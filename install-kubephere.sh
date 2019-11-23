#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
    for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
        source ${SCRIPT}
    done
fi

# 安装 KubeSphere (端口 30880 默认密码 admin/P@88w0rd)
install_kubephere() {
    info "install_kubephere..."

    if ! command_exists helm; then
        fatal "Wanna install KubeSphere, please install helm first."
    fi

    kubectl apply -f https://raw.githubusercontent.com/kubesphere/ks-installer/master/kubesphere-minimal.yaml
}

install_kubephere
