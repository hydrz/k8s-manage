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
		Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external --hostname-override=${REGION_ID}.${INSTANCE_ID} --provider-id=${REGION_ID}.${INSTANCE_ID}"
	EOF

    CA_DATA=$(cat /etc/kubernetes/pki/ca.crt | base64 -w 0)

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

    cat <<-EOF >/etc/kubernetes/cloud-controller-manager.conf
		apiVersion: v1
		kind: ConfigMap
		metadata:
		  name: cloud-controller-manager
		  namespace: kube-system
		data:
		  cloud-controller-manager.conf: |-
		    kind: Config
		    contexts:
		      - context:
		          cluster: kubernetes
		          user: system:cloud-controller-manager
		          name: system:cloud-controller-manager@kubernetes
		    current-context: system:cloud-controller-manager@kubernetes
		    users:
		      - name: system:cloud-controller-manager
		        user:
		        tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
		    apiVersion: v1
		    clusters:
		      - cluster:
		          certificate-authority-data: $CA_DATA
		          server: $(k cluster-info | xargs -n 1 | grep http | head -1)
		          name: kubernetes
	EOF

    cat ${PWD}/yaml/cloud-controller-manager.yml |
        sed "s?\${CLUSTER_CIDR}?${CLUSTER_CIDR}?" |
        kubectl apply -f -

    # 取消初始化污点
    # kubectl taint nodes --all node.cloudprovider.kubernetes.io/uninitialized-
}

install_aliyun_cloud
