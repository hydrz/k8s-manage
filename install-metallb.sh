#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
	for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
		source ${SCRIPT}
	done
fi

# 安装 metallb 负载均衡网络
install_metallb() {
	info "install_metallb..."

	if ! command_exists helm; then
		fatal "Wanna install metallb, please install helm first."
	fi

	cat <<-EOF | helm install --name metallb --namespace metallb-system stable/metallb -f -
		configInline:
		  address-pools:
		  - name: default
		    protocol: layer2
		    addresses:
		    - ${METALLB_CIDR}
	EOF
}

install_metallb
