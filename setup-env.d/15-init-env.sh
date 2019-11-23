#!/bin/sh
# 初始化常用常量

# --- 获取公网IP ---
init_public_ip() {
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short)
    check_ip "$PUBLIC_IP" || PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com)
    check_ip "$PUBLIC_IP" || fatal "Cannot detect this server's public IP. Edit the script and manually enter it."
}

# --- 操作系统类型 ---
init_os() {
    OS=$(echo $(uname) | tr '[:upper:]' '[:lower:]')

    case "$OS" in
    # Minimalist GNU for Windows
    mingw*) OS='windows' ;;
    esac
}

# --- 系统架构 ---
init_arch() {
    ARCH=$(uname -m)
    case $ARCH in
    armv5*) ARCH="armv5" ;;
    armv6*) ARCH="armv6" ;;
    armv7*) ARCH="arm" ;;
    aarch64) ARCH="arm64" ;;
    x86) ARCH="386" ;;
    x86_64) ARCH="amd64" ;;
    i686) ARCH="386" ;;
    i386) ARCH="386" ;;
    esac
}

# --- 发行版 ---
init_lsb() {
    LSB_DIST=""
    DIST_VERSION=""
    # Every system that we officially support has /etc/os-release
    if [ -r /etc/os-release ]; then
        LSB_DIST="$(. /etc/os-release && echo "$ID")"
    fi

    LSB_DIST="$(echo "${LSB_DIST}" | tr '[:upper:]' '[:lower:]')"

    case "${LSB_DIST}" in

    ubuntu)
        if command_exists lsb_release; then
            DIST_VERSION="$(lsb_release --codename | cut -f2)"
        fi
        if [ -z "${DIST_VERSION}" ] && [ -r /etc/lsb-release ]; then
            DIST_VERSION="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
        fi
        ;;

    debian | raspbian)
        DIST_VERSION="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
        case "${DIST_VERSION}" in
        10)
            DIST_VERSION="buster"
            ;;
        9)
            DIST_VERSION="stretch"
            ;;
        8)
            DIST_VERSION="jessie"
            ;;
        esac
        ;;

    centos)
        if [ -z "${DIST_VERSION}" ] && [ -r /etc/os-release ]; then
            DIST_VERSION="$(. /etc/os-release && echo "$DOCKER_VERSION_ID")"
        fi
        ;;

    rhel | ol | sles)
        ee_notice "${LSB_DIST}"
        exit 1
        ;;

    *)
        if command_exists lsb_release; then
            DIST_VERSION="$(lsb_release --release | cut -f2)"
        fi
        if [ -z "${DIST_VERSION}" ] && [ -r /etc/os-release ]; then
            DIST_VERSION="$(. /etc/os-release && echo "$DOCKER_VERSION_ID")"
        fi
        ;;

    esac

    # 检查发行版分支
    # Check for lsb_release command existence, it usually exists in forked distros
    if command_exists lsb_release; then
        # Check if the `-u` option is supported
        set +e
        lsb_release -a -u >/dev/null 2>&1
        lsb_release_exit_code=$?
        set -e

        # Check if the command has exited successfully, it means we're in a forked distro
        if [ "$lsb_release_exit_code" = "0" ]; then
            # Print info about current distro
            cat <<-EOF
			You're using '${LSB_DIST}' version '${DIST_VERSION}'.
			EOF

            # Get the upstream release info
            LSB_DIST=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
            DIST_VERSION=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')

            # Print info about upstream distro
            cat <<-EOF
			Upstream release is '${LSB_DIST}' version '${DIST_VERSION}'.
			EOF
        else
            if [ -r /etc/debian_version ] && [ "${LSB_DIST}" != "ubuntu" ] && [ "${LSB_DIST}" != "raspbian" ]; then
                if [ "${LSB_DIST}" = "osmc" ]; then
                    # OSMC runs Raspbian
                    LSB_DIST=raspbian
                else
                    # We're Debian and don't even know it!
                    LSB_DIST=debian
                fi
                DIST_VERSION="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
                case "${DIST_VERSION}" in
                10)
                    DIST_VERSION="buster"
                    ;;
                9)
                    DIST_VERSION="stretch"
                    ;;
                8 | 'Kali Linux 2')
                    DIST_VERSION="jessie"
                    ;;
                esac
            fi
        fi
    fi
}

init_public_ip
init_os
init_arch
init_lsb
