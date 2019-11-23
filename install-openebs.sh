#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
    for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
        source ${SCRIPT}
    done
fi

# 安装 openebs 本地存储
install_openebs() {
    info "install_openebs..."

    if ! command_exists helm; then
        fatal "Wanna install openebs, please install helm first."
    fi

    helm repo add hydrz https://hydrz.github.io/helm-charts/
    helm repo update
    helm install --name=openebs --namespace openebs-system hydrz/openebs-lite \
        --set storageClass.isDefaultClass=true \
        --set ndm.nodeSelector."node-role\.kubernetes\.io\/master"= \
        --set localprovisioner.nodeSelector."node-role\.kubernetes\.io\/master"= \
        --set ndmOperator.nodeSelector."node-role\.kubernetes\.io\/master"=
}

install_openebs
