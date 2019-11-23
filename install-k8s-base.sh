#!/bin/sh
set -e

# 安装 kubelet kubeadm kubectl
install_k8s_base() {
    info "install kubelet kubeadm kubectl..."
    run_as_root '/sbin/swapoff -a'

    case "${LSB_DIST}" in
    ubuntu | debian | raspbian)
        apt_repo="deb [arch=${ARCH}] https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"
        (
            run_as_root "curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - "
            run_as_root "echo $apt_repo >/etc/apt/sources.list.d/kubernetes.list"
            run_as_root 'apt-get update'
        )

        local pkg_version=""
        if [ -n "${K8S_VERSION}" ]; then
            local pkg_pattern="$(echo "${K8S_VERSION}" | sed "s/-/.*/g").*-00"
            local search_command="apt-cache madison 'kubeadm' | grep '$pkg_pattern' | head -1 | awk '{\$1=\$1};1' | cut -d' ' -f 3"
            pkg_version="$(run_as_root "$search_command")"
            info "Searching repository for K8S_VERSION '${K8S_VERSION}'"
            info "$search_command"
            if [ -z "$pkg_version" ]; then
                fatal "'${K8S_VERSION}' not found amongst apt-cache madison results"
            fi
        fi

        run_as_root "apt-get install -y --no-install-recommends kubelet=$pkg_version kubeadm=$pkg_version kubectl=$pkg_version"
        ;;

    centos | fedora)
        if [ "${LSB_DIST}" = "fedora" ]; then
            local pkg_manager="dnf"
            local config_manager="dnf config-manager"
        else
            local pkg_manager="yum"
            local config_manager="yum-config-manager"
        fi

        run_as_root "cat <<-EOF >/etc/yum.repos.d/kubernetes.repo
			[kubernetes]
			name=Kubernetes
			baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
			enabled=1
			gpgcheck=1
			repo_gpgcheck=1
			gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
		EOF"

        run_as_root "$pkg_manager makecache"

        local pkg_version=""
        if [ -n "${K8S_VERSION}" ]; then
            local pkg_pattern="$(echo "${K8S_VERSION}" | sed "s/-/.*/g").*-0"
            local search_command="$pkg_manager list --showduplicates 'kubeadm' | grep '$pkg_pattern' | tail -1 | awk '{print \$2}'"
            pkg_version="$(run_as_root "$search_command")"
            info "Searching repository for K8S_VERSION '${K8S_VERSION}'"
            info "$search_command"
            if [ -z "$pkg_version" ]; then
                fatal "'${K8S_VERSION}' not found amongst $pkg_manager list results"
            fi
            # Cut out the epoch and prefix with a '-'
            pkg_version="$(echo "$pkg_version" | cut -d':' -f 2)"
        fi

        run_as_root "$pkg_manager install -y kubelet-$pkg_version kubeadm-$pkg_version kubectl-$pkg_version"
        ;;
    *)
        fatal "Unsupported distribution '${LSB_DIST}'"
        ;;
    esac

    # 调参运行
    run_as_root cat <<-EOF >/usr/lib/sysctl.d/20-k8s.conf
        net.ipv4.ip_forward=1
        net.ipv4.ip_local_reserved_ports=30000-32767
        net.bridge.bridge-nf-call-iptables=1
        net.bridge.bridge-nf-call-arptables=1
        net.bridge.bridge-nf-call-ip6tables=1
	EOF
    run_as_root sysctl --system >/dev/null

    # Restart
    run_as_root systemctl daemon-reload
    run_as_root systemctl enable kubelet
    run_as_root systemctl restart kubelet

    # 阿里云拉取镜像
    for i in $(kubeadm config images list); do
        imageName=${i#k8s.gcr.io/}
        docker pull registry.aliyuncs.com/google_containers/$imageName
        docker tag registry.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
        docker rmi registry.aliyuncs.com/google_containers/$imageName
    done
}

install_k8s_base
