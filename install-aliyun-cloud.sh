#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
    for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
        source ${SCRIPT}
    done
fi

# 安装 cloud-provider-alibaba-cloud
install_aliyun_cloud() {
    info "install_aliyun_cloud..."

    if [ -z "$ACCESS_KEY_ID" ]; then
        fatal "ACCESS_KEY_ID must be provided"
    fi

    if [ -z "$ACCESS_KEY_SECRET" ]; then
        fatal "ACCESS_KEY_SECRET must be provided"
    fi

    META_EP=http://100.100.100.200/latest/meta-data
    REGION_ID=$(curl -s $META_EP/region-id)
    INSTANCE_ID=$(curl -s $META_EP/instance-id)
    run_as_root cat <<-EOF >/usr/lib/systemd/system/kubelet.service.d/20-aliyun.conf
		[Service]
		Environment="KUBELET_EXTRA_ARGS=--hostname-override=${REGION_ID}.${INSTANCE_ID} --provider-id=${REGION_ID}.${INSTANCE_ID}"
	EOF

    cat <<-EOF | kubectl apply -f -
		apiVersion: v1
		data:
		  special.keyid: $ACCESS_KEY_ID
		  special.keysecret: $ACCESS_KEY_SECRET
		kind: ConfigMap
		metadata:
		  name: cloud-config
		  namespace: kube-system
	EOF

    MANAGER_CONFIG=$(cat /etc/kubernetes/controller-manager.conf)

    kubectl --namespace kube-system create configmap cloud-controller-manager \
        --from-file=cloud-controller-manager.conf=/etc/kubernetes/controller-manager.conf

    cat ${PWD}/yaml/cloud-controller-manager.yml |
        sed "s?\${CLUSTER_CIDR}?${CLUSTER_CIDR}?" |
        kubectl apply -f -
}

install_aliyun_cloud
