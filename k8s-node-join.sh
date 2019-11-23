#!/bin/sh
set -e

PWD=$(dirname $(readlink -f "$0"))

if [ -d "${SETUP_ENV:=${PWD}/setup-env.d}" ]; then
    for SCRIPT in $(ls "${SETUP_ENV}/"[0-9]*.sh | sort); do
        source ${SCRIPT}
    done
fi

if [ -z "${K8S_ADDRESS}" ]; then
    fatal "K8S_ADDRESS is not defined."
fi

if [ -z "${K8S_TOKEN}" ]; then
    fatal "K8S_ADDRESS is defined, but K8S_TOKEN is not defined."
fi

kubeadm join ${K8S_ADDRESS} --token ${K8S_TOKEN} ${K8S_OPS} --discovery-token-unsafe-skip-ca-verification
