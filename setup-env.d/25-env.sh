#!/bin/sh

# 环境变量

# docker 配置
: ${DOCKER_VERSION:="18.09"}
: ${DOCKER_CHANNEL:="stable"}

# k8s 配置
: ${TAINT_NODES:="false"}
: ${K8S_VERSION:="1.15"}
: ${ADVERTISE_ADDRESS:="0.0.0.0"}
: ${CLUSTER_DOMAIN:="cluster.local"}
: ${CLUSTER_CIDR:="192.168.240.0/24"}
: ${SERVICE_CIDR:="192.168.241.0/24"}

# helm 配置
: ${INSTALL_HELM:="true"}
: ${HELM_DOWNLOAD_URL:="https://mirrors.huaweicloud.com/helm"}
: ${HELM_VERSION:="v2.16.1"}
: ${HELM_STABLE_REPO_URL:="https://mirror.azure.cn/kubernetes/charts/"}
: ${HELM_BIN_INSTALL_DIR:="/usr/local/bin"}

# 扩展
: ${INSTALL_OPENEBS:="false"}
: ${INSTALL_METALLB:="false"}
: ${INSTALL_KUBESPHERE:="false"}

# 阿里云配置(用于使用负载均衡)
: ${INSTALL_ALIYUN_CLOUD:="false"}
: ${ACCESS_KEY_ID:=""}
: ${ACCESS_KEY_SECRET:=""}

# 常量
TMP_ROOT="$(mktemp -dt k8s-manage-XXXXXX)"
