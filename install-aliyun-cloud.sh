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

    hostnamectl set-hostname ${REGION_ID}.${INSTANCE_ID}

    run_as_root mkdir -p /etc/sysconfig/
    run_as_root echo "KUBELET_EXTRA_ARGS=--cloud-provider=external --hostname-override=${REGION_ID}.${INSTANCE_ID} --provider-id=${REGION_ID}.${INSTANCE_ID}" >/etc/sysconfig/kubelet

    # kubectl -n kube-system get ds kube-proxy -o yaml |
        # sed "s/- --hostname-override=.*/- --hostname-override=${REGION_ID}.${INSTANCE_ID}/" |
        # kubectl -n kube-system apply -f -

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

    kubectl --namespace kube-system create configmap cloud-controller-manager \
        --from-file=cloud-controller-manager.conf=/etc/kubernetes/controller-manager.conf

    cat ${PWD}/config/cloud-controller-manager.yml |
        sed "s?\${CLUSTER_CIDR}?${CLUSTER_CIDR}?" |
        kubectl apply -f -

    run_as_root systemctl daemon-reload
    run_as_root systemctl enable kubelet
    run_as_root systemctl restart kubelet
}

install_aliyun_cloud
