#!/bin/sh
set -e

if [ -z "${K8S_ADDRESS}" ]; then
    fatal "K8S_ADDRESS is not defined."
fi

if [ -z "${K8S_TOKEN}" ]; then
    fatal "K8S_ADDRESS is defined, but K8S_TOKEN is not defined."
fi

kubeadm join ${K8S_ADDRESS} --token ${K8S_TOKEN} ${K8S_OPS} --discovery-token-unsafe-skip-ca-verification
