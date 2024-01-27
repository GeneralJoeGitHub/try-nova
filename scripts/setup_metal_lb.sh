#!/bin/bash

# Setup Metal Load Balancer for a workload cluster
echo "--- Configuring Metal Load Balancer for cluster using kubeconfig: $1"
KUBECONFIG="$1" kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
KUBECONFIG="$1" kubectl patch -n metallb-system deploy controller --type='json' -p '[{"op": "add", "path": "/spec/strategy/rollingUpdate/maxUnavailable", "value": 0}]'

# subnet for kind bridge: https://kind.sigs.k8s.io/docs/user/loadbalancer/
prefix=$(docker inspect kind|jq -r '.[].IPAM.Config[]|select(.Gateway|contains("."))|.Gateway'|cut -d. -f1-2)
export RANGE_START=${prefix}.255.200
export RANGE_END=${prefix}.255.255
envsubst < "${REPO_ROOT}/scripts/metal_lb_addrpool_template.yaml" > "${REPO_ROOT}/metal_lb_addrpool.yaml"
echo "--- Metal LB config:"
cat ${REPO_ROOT}/metal_lb_addrpool.yaml
KUBECONFIG="$1" kubectl -n metallb-system wait pod --all --timeout=1200s --for=condition=Ready
KUBECONFIG="$1" kubectl -n metallb-system wait deploy controller --timeout=1200s --for=condition=Available
KUBECONFIG="$1" kubectl -n metallb-system wait apiservice v1beta1.metallb.io --timeout=1200s --for=condition=Available
KUBECONFIG="$1" kubectl apply -f ./metal_lb_addrpool.yaml
rm ${REPO_ROOT}/metal_lb_addrpool.yaml || true
