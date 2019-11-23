#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
    for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
        source ${SCRIPT}
    done
fi

# init k8s
init_k8s() {
    info "init_k8s..."

    run_as_root mkdir -p /etc/kubernetes

    CLUSTER_DNS=$(echo ${SERVICE_CIDR} | awk -F '/' '{print $1}' | awk -F '.' '{print $1"."$2"."$3".""10"}')

    KUBEADM_INIT_CONFIG="/etc/kubernetes/kubelet.yaml"

    kubeadm config print init-defaults --component-configs KubeletConfiguration |
        sed "s?10.96.0.10?${CLUSTER_DNS}?g" |
        sed "s?10.96.0.0/12?${SERVICE_CIDR}?g" |
        sed "s/advertiseAddress.*/advertiseAddress: ${ADVERTISE_ADDRESS}/" |
        sed "s/dnsDomain.*/dnsDomain: ${CLUSTER_DOMAIN}/" |
        sed "s/kubernetesVersion.*/kubernetesVersion: \"$(kubeadm version -o short)\"/" |
        sed "s/enableControllerAttachDetach.*/enableControllerAttachDetach: false/" |
        sed "/serviceSubnet/a\  podSubnet: \"${CLUSTER_CIDR}\"" |
        sed "/apiServer/a\  certSANs:\n  - ${PUBLIC_IP}" |
        # sed "/certificatesDir/a\controlPlaneEndpoint: ${PUBLIC_IP}:6443" |
        run_as_root tee ${KUBEADM_INIT_CONFIG} >/dev/null

    run_as_root kubeadm init --config=${KUBEADM_INIT_CONFIG} ${K8S_OPS} --ignore-preflight-errors=NumCPU

    # 写入配置
    mkdir -p ${HOME}/.kube
    run_as_root /bin/cp -rf /etc/kubernetes/admin.conf ${HOME}/.kube/config
    run_as_root chown $(id -u):$(id -g) ${HOME}/.kube/config

    # 安装网络组件
    # curl -sfL https://docs.projectcalico.org/v3.10/manifests/calico.yaml |
    #     sed -e "s?192.168.0.0/16?${CLUSTER_CIDR}?g" |
    #     kubectl apply -f -
    curl -sfL https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml |
        sed -e "s?10.244.0.0/16?${CLUSTER_CIDR}?g" |
        sed -e "s?quay.io?quay.azk8s.cn?g" |
        kubectl apply -f -

    # 代码提示
    run_as_root kubectl completion bash >/etc/bash_completion.d/kubectl
    run_as_root echo 'alias k=kubectl' >>/etc/bash_completion.d/kubectl
    run_as_root echo 'complete -F __start_kubectl k' >>/etc/bash_completion.d/kubectl

    # 取消污点
    [ "${TAINT_NODES}" = "true" ] && kubectl taint nodes --all node-role.kubernetes.io/master-
}

init_k8s
