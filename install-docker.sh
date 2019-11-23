#!/bin/sh
set -e

source bootstraps.sh

# 安装 Docker
install_docker() {
    info "install_docker..."

    curl -fsSL https://get.daocloud.io/docker | sed "s/sleep 20/sleep 3/" | VERSION=${DOCKER_VERSION} bash -s docker --mirror Aliyun

    ## Create /etc/docker directory.
    run_as_root 'mkdir -p /etc/docker'

    # Setup daemon.
    run_as_root cat <<-EOF >/etc/docker/daemon.json
	{
	    "exec-opts": ["native.cgroupdriver=systemd"],
	    "log-driver": "json-file",
	    "log-opts": {
	        "max-size": "100m"
	    },
	    "storage-driver": "overlay2",
	    "registry-mirrors": [
	        "https://2q2p53i3.mirror.aliyuncs.com",
	        "https://053f3ac1058010d30f08c00ec2aca420.mirror.swr.myhuaweicloud.com"
	    ]
	}
	EOF

    run_as_root mkdir -p /etc/systemd/system/docker.service.d

    # docker_as_nonroot
    run_as_root usermod -aG docker $(id -un 2>/dev/null || true)

    # Restart
    run_as_root systemctl daemon-reload
    run_as_root systemctl enable docker
    run_as_root systemctl restart docker
}

install_docker
