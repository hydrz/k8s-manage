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
        run_as_root 'apt-get update'
        run_as_root "DEBIAN_FRONTEND=noninteractive apt-get install -y $pre_reqs"
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
        run_as_root "$pkg_manager install -y $pre_reqs"
        ;;
    *)
        fatal "Unsupported distribution '${LSB_DIST}'"
        ;;
    esac
}

pre_install
