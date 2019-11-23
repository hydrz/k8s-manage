#!/bin/sh

# --- 依赖安装 ---
pre_install() {
    info "install_dependencies..."

    case "${LSB_DIST}" in
    ubuntu | debian | raspbian)
        if [ "${LSB_DIST}" = "debian" ]; then
            # libseccomp2 does not exist for debian jessie main repos for aarch64
            if [ "$(uname -m)" = "aarch64" ] && [ "${DIST_VERSION}" = "jessie" ]; then
                add_debian_backport_repo "${DIST_VERSION}"
            fi
        fi

        local pre_reqs="apt-transport-https ca-certificates curl bash-completion"
        if ! command_exists gpg; then
            pre_reqs="$pre_reqs gnupg"
        fi
        run_as_root apt-get update
        run_as_root DEBIAN_FRONTEND=noninteractive apt-get install -y $pre_reqs
        ;;
    centos | fedora)
        local pre_reqs="curl bash-completion"
        if [ "${LSB_DIST}" = "fedora" ]; then
            local pkg_manager="dnf"
            local config_manager="dnf config-manager"
            pre_reqs="$pre_reqs dnf-plugins-core"
        else
            local pkg_manager="yum"
            local config_manager="yum-config-manager"
            pre_reqs="$pre_reqs yum-utils"
        fi
        run_as_root $pkg_manager install -y $pre_reqs
        ;;
    *)
        fatal "Unsupported distribution '${LSB_DIST}'"
        ;;
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

# --- 关闭selinux ---
selinux_disable() {
    if command_exists getenforce && [ "$(getenforce)" = "Enabled" ]; then
        run_as_root setenforce 0
        run_as_root sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        info "Selinux disabled success!"
    fi
}

# --- 关闭swap ---
swap_disable() {
    run_as_root swapoff -a
    run_as_root sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab
}

# --- 关闭防火墙 ---
firewalld_stop() {
    if [ "$(systemctl is-active firewalld)" = "active" ]; then
        run_as_root systemctl disable firewalld
        run_as_root systemctl stop firewalld
        info "Firewall disabled success!"
    fi
}

# --- 优化journald配置 ---
journald_config() {
    mkdir /var/log/journal
    mkdir /etc/systemd/journald.conf.d
    cat >/etc/systemd/journald.conf.d/99-prophet.conf <<-EOF
		[Journal]
		# 持久化保存到磁盘
		Storage=persistent
		# 压缩历史日志
		Compress=yes
		SyncIntervalSec=5m
		RateLimitInterval=30s
		RateLimitBurst=1000
		# 最大占用空间 10G
		SystemMaxUse=10G
		# 单日志文件最大 200M
		SystemMaxFileSize=200M
		# 日志保存时间 2 周
		MaxRetentionSec=2week
		# 不将日志转发到 syslog
		ForwardToSyslog=no
	EOF
    systemctl restart systemd-journald
}

pre_install
selinux_disable
swap_disable
firewalld_stop
