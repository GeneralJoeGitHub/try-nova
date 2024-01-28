#!/usr/bin/env bash

# (Pawel)
# Unfortunately there are some hacks needed to setup two kind cluster where one can reach Nova API Server over NodePort
# and at the same time user can reach Nova API Server over MetalLB IP.
# This requires generating kube-apiserver-csr with both MetalLB IP and kind-cp node IP.
# Additionally, we want to have two different kubeconfigs for Nova Control Plane:
# 1. For Nova Agent, which will talk to Nova API Server over kind-cp-node-ip:NodePort
# 2. For human user, which will talk to Nova API Server over MetalLB IP.

set -e

sysctl -wq fs.inotify.max_user_watches=524288
sysctl -wq fs.inotify.max_user_instances=512

export REPO_ROOT=$(git rev-parse --show-toplevel)
export config_name="${REPO_ROOT}/kubeconfig-e2e-test"

# Bootstrap two kind clusters
export cp_cluster="cp"
export workload_cluster_1="workload-1"
export workload_cluster_2="workload-2"

export cp_cluster_config="${config_name}-${cp_cluster}"
export workload_cluster_1_config="${config_name}-${workload_cluster_1}"
export workload_cluster_2_config="${config_name}-${workload_cluster_2}"

export CP_NOVA_K8S_VERSION=${NOVA_E2E_K8S_VERSION:-"v1.25.1"}
export NOVA_K8S_VERSION=${NOVA_E2E_K8S_VERSION:-"v1.25.1"}

export cp_node_image="kindest/node:${CP_NOVA_K8S_VERSION}"
export node_image="kindest/node:${NOVA_K8S_VERSION}"

printf "\n--- Creating three kind clusters\n\n"
source ${REPO_ROOT}/scripts/setup_kind_cluster.sh
printf "\n--- Clusters created\n"

# Setup Metal Load Balancer for CP cluster:
printf "\n--- Configuring Metal Load Balancer for kind-cp cluster using kubeconfig: ${cp_cluster_config}\n\n"
source ${REPO_ROOT}/scripts/setup_metal_lb.sh "${cp_cluster_config}"
printf "\n--- Metal Load Balancer installed in kind-cp cluster.\n"

# Setup Metal Load Balancer for Workload 1 cluster:
printf "\n--- Configuring Metal Load Balancer for kind-workload-1 cluster using kubeconfig: ${workload_cluster_1_config}\n\n"
source ${REPO_ROOT}/scripts/setup_metal_lb.sh "${workload_cluster_1_config}"
printf "\n--- Metal Load Balancer installed in kind-workload-1 cluster.\n"

# Setup Metal Load Balancer for Workload 2 cluster:
printf "\n--- Configuring Metal Load Balancer for kind-workload-2 cluster using kubeconfig: ${workload_cluster_2_config}\n\n"
source ${REPO_ROOT}/scripts/setup_metal_lb.sh "${workload_cluster_2_config}"
printf "\n--- Metal Load Balancer installed in kind-workload-2 cluster.\n"

printf "\n--- Clusters ready for nova-scheduler and nova-agent deployments.\n"

# Get IP of a node where Nova APIServer runs and it's exposed on 32222 hardcoded NodePort.
nova_node_ip=$(KUBECONFIG="${cp_cluster_config}" kubectl get nodes -o json|jq -r '.items[]|select(.metadata.name=="cp-control-plane").status.addresses[]|select(.type=="InternalIP").address')
printf "\nnova_node_ip: ${nova_node_ip}\n"

SCHEDULER_IMAGE_REPO="elotl/nova-scheduler-trial"
AGENT_IMAGE_REPO="elotl/nova-agent-trial"
APISERVER_ENDPOINT_PATCH="${nova_node_ip}:32222"
APISERVER_SERVICE_NODEPORT="32222"

# Deploy Nova control plane to kind-cp
KUBECONFIG="${cp_cluster_config}" NOVA_NODE_IP=${nova_node_ip} kubectl nova install cp --image-repository "${SCHEDULER_IMAGE_REPO}" --context kind-cp nova
KUBECONFIG="${workload_cluster_1_config}" kubectl create ns elotl
KUBECONFIG="${workload_cluster_2_config}" kubectl create ns elotl

while ! KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig"  kubectl get secret nova-cluster-init-kubeconfig --namespace elotl;
do
  printf "\nWaiting for nova-cluster-init-kubeconfig secret creation\n"
  sleep 5
done

KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${workload_cluster_1_config}" kubectl apply -f -
KUBECONFIG="${HOME}/.nova/nova/nova-kubeconfig" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${workload_cluster_2_config}" kubectl apply -f -

# Deploy Nova agent to kind-workload-1 and kind-workload-2
KUBECONFIG="${workload_cluster_1_config}" kubectl nova install agent --image-repository "${AGENT_IMAGE_REPO}" --context kind-workload-1 kind-workload-1
KUBECONFIG="${workload_cluster_2_config}" kubectl nova install agent --image-repository "${AGENT_IMAGE_REPO}" --context kind-workload-2 kind-workload-2

if [ "${SUDO_USER}" ];
then
  USER_HOME=$(getent passwd ${SUDO_USER}|cut -d: -f6)
  mv ${HOME}/.nova ${USER_HOME}
  chown -R ${SUDO_USER}:${SUDO_USER} ${USER_HOME}/.nova
  chown ${SUDO_USER}:${SUDO_USER} ${config_name}-*
  printf "\nDirectory ${HOME}/.nova has been migrated to ${USER_HOME}/.nova\n"
else
  USER_HOME=${HOME}
fi

printf "\nTo interact with Nova, run:\n\nexport KUBECONFIG=${USER_HOME}/.nova/nova/nova-kubeconfig:${cp_cluster_config}:${workload_cluster_1_config}:${workload_cluster_2_config}\n\nkubectl get clusters --context=nova\n\n"
