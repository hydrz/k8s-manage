#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
	for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
		source ${SCRIPT}
	done
fi

# 安装 helm
install_helm() {
	info "install_helm..."
	HELM_TMP="${TMP_ROOT}/helm"
	mkdir -p ${HELM_TMP}
	wget -O ${TMP_ROOT}/helm.tar.gz ${HELM_DOWNLOAD_URL}/$HELM_VERSION/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz
	tar xf ${TMP_ROOT}/helm.tar.gz -C "${HELM_TMP}"
	run_as_root cp ${HELM_TMP}/${OS}-${ARCH}/helm ${BIN_INSTALL_DIR}/helm
	run_as_root chmod +x ${BIN_INSTALL_DIR}/helm

	cat <<-EOF >${HELM_TMP}/helm-rbac.yaml
		apiVersion: v1
		kind: ServiceAccount
		metadata:
		  name: tiller
		  namespace: kube-system
		---
		apiVersion: rbac.authorization.k8s.io/v1beta1
		kind: ClusterRoleBinding
		metadata:
		  name: tiller
		roleRef:
		  apiGroup: rbac.authorization.k8s.io
		  kind: ClusterRole
		  name: cluster-admin
		subjects:
		  - kind: ServiceAccount
		    name: tiller
		    namespace: kube-system
	EOF
	kubectl apply -f ${HELM_TMP}/helm-rbac.yaml
	helm init --upgrade --service-account tiller -i registry.aliyuncs.com/google_containers/tiller:${HELM_VERSION} \
		--stable-repo-url ${HELM_STABLE_REPO_URL}
	run_as_root helm completion bash >/etc/bash_completion.d/helm
}

install_helm
