#!/usr/bin/env bash

set -e
#set -x

sysctl -w fs.inotify.max_user_watches=524288
sysctl -w fs.inotify.max_user_instances=512

REPO_ROOT=$(git rev-parse --show-toplevel)

# (Pawel)
# Unfortunately there are some hacks needed to setup two kind cluster where one can reach Nova API Server over NodePort
# and at the same time user can reach Nova API Server over MetalLB IP.
# This requires generating kube-apiserver-csr with both MetalLB IP and kind-cp node IP.
# Additionally, we want to have two different kubeconfigs for Nova Control Plane:
# 1. For Nova Agent, which will talk to Nova API Server over kind-cp-node-ip:NodePort
# 2. For human user, which will talk to Nova API Server over MetalLB IP.
export KUBECONFIG=${REPO_ROOT}/kubeconfig-e2e-test

# Bootstrap two kind clusters
source ${REPO_ROOT}/scripts/setup_kind_cluster.sh


# Get IP of a node where Nova APIServer runs and it's exposed on 32222 hardcoded NodePort.
nova_node_ip=$(KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-cp" kubectl get nodes -o=jsonpath='{.items[0].status.addresses[0].address}' | xargs)
printf "nova_node_ip: ${nova_node_ip}\n"

export SCHEDULER_IMAGE_REPO="elotl/nova-scheduler-trial"
export AGENT_IMAGE_REPO="elotl/nova-agent-trial"
export APISERVER_ENDPOINT_PATCH="${nova_node_ip}:32222"
export APISERVER_SERVICE_NODEPORT="32222"

# Deploy Nova control plane to kind-cp
KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-cp" NOVA_NODE_IP=${nova_node_ip} kubectl nova install cp --image-repository "${SCHEDULER_IMAGE_REPO}" --context kind-cp nova

KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-1" kubectl create ns elotl
KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-2" kubectl create ns elotl

while ! KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig"  kubectl get secret nova-cluster-init-kubeconfig --namespace elotl;
do
  echo "Waiting for nova-cluster-init-kubeconfig secret creation"; sleep 5;
done

KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-1" kubectl apply -f -
KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-2" kubectl apply -f -

# Deploy Nova agent to kind-workload-1 and kind-workload-2
KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-1" kubectl nova install agent --image-repository "${AGENT_IMAGE_REPO}" --context kind-workload-1 kind-workload-1
KUBECONFIG="${REPO_ROOT}/kubeconfig-e2e-test-workload-2" kubectl nova install agent --image-repository "${AGENT_IMAGE_REPO}" --context kind-workload-2 kind-workload-2

if [ "${SUDO_USER}" ];
then
  USER_HOME=$(getent passwd ${SUDO_USER}|cut -d: -f6)
  mv ${HOME}/.nova ${USER_HOME}
  chown -R ${SUDO_USER} ${USER_HOME}/.nova
  printf "\nDirectory ${HOME}/.nova has been migrated to ${USER_HOME}/.nova\n"
  printf "\nTo interact with Nova, run:\n\nexport KUBECONFIG=${USER_HOME}/.nova/nova/nova-kubeconfig:${REPO_ROOT}/kubeconfig-e2e-test-cp:${REPO_ROOT}/kubeconfig-e2e-test-workload-1:${REPO_ROOT}/kubeconfig-e2e-test-workload-2\nkubectl get clusters --context=nova\n\n"
else
  export KUBECONFIG=${HOME}/.nova/nova/nova-kubeconfig:${REPO_ROOT}/kubeconfig-e2e-test-cp:${REPO_ROOT}/kubeconfig-e2e-test-workload-1:${REPO_ROOT}/kubeconfig-e2e-test-workload-2
fi
