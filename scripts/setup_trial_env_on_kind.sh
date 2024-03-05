#!/usr/bin/env bash

# (Pawel)
# Unfortunately there are some hacks needed to setup two kind cluster where one can reach Nova API Server over NodePort
# and at the same time user can reach Nova API Server over MetalLB IP.
# This requires generating kube-apiserver-csr with both MetalLB IP and kind-cp node IP.
# Additionally, we want to have two different kubeconfigs for Nova Control Plane:
# 1. For Nova Agent, which will talk to Nova API Server over kind-cp-node-ip:NodePort
# 2. For human user, which will talk to Nova API Server over MetalLB IP.

set -e

if [ "${SUDO_USER}" ];
then
  user_home=$(getent passwd ${SUDO_USER}|cut -d: -f6)
  if [ -d ${user_home}/.nova ];
  then
    printf "\nDirectory ${user_home}/.nova exists.  Please backup and/or remove directory and try again.\n\n"
    exit
  fi
fi

sysctl -wq fs.inotify.max_user_watches=524288
sysctl -wq fs.inotify.max_user_instances=512

pwd_0=${PWD}/${0#./}
script_dir=${pwd_0%/*}

cluster_config_prefix="${script_dir}/kubeconfig-e2e-test-"

# Bootstrap kind clusters
cp_cluster="cp"
workload_cluster_1="workload-1"
workload_cluster_2="workload-2"

CP_NOVA_K8S_VERSION=${NOVA_E2E_K8S_VERSION:-"v1.25.1"}
NOVA_K8S_VERSION=${NOVA_E2E_K8S_VERSION:-"v1.25.1"}

api_version="kind.x-k8s.io/v1alpha4"
cp_node_image="kindest/node:${CP_NOVA_K8S_VERSION}"
cp_node_port=32222
node_image="kindest/node:${NOVA_K8S_VERSION}"

cp_cluster_config="${cluster_config_prefix}${cp_cluster}"
workload_cluster_1_config="${cluster_config_prefix}${workload_cluster_1}"
workload_cluster_2_config="${cluster_config_prefix}${workload_cluster_2}"

printf "\n--- Creating kind clusters\n\n"
source ${script_dir}/setup_kind_cluster.sh
printf "\n--- Clusters created\n"

# Get kind information
inspect_kind=$(docker inspect kind|jq -c '.[]|select(.Name=="kind")')

# Get subnet for kind bridge: https://kind.sigs.k8s.io/docs/user/loadbalancer/
prefix=$(echo $inspect_kind|jq -r '.IPAM.Config[]|select(.Gateway != null)|select(.Gateway|contains(".")).Subnet'|cut -d. -f1-2)

# Setup Metal Load Balancer for CP cluster:
printf "\n--- Configuring Metal Load Balancer for kind-${cp_cluster} cluster using kubeconfig: ${cp_cluster_config}\n"
source ${script_dir}/setup_metal_lb.sh "${cp_cluster_config}" "${prefix}.100.1" "${prefix}.100.100"
printf "\n--- Metal Load Balancer installed in kind-${cp_cluster} cluster.\n"

# Setup Metal Load Balancer for Workload 1 cluster:
printf "\n--- Configuring Metal Load Balancer for kind-${workload_cluster_1} cluster using kubeconfig: ${workload_cluster_1_config}\n"
source ${script_dir}/setup_metal_lb.sh "${workload_cluster_1_config}" "${prefix}.101.1" "${prefix}.101.100"
printf "\n--- Metal Load Balancer installed in kind-${workload_cluster_1} cluster.\n"

# Setup Metal Load Balancer for Workload 2 cluster:
printf "\n--- Configuring Metal Load Balancer for kind-${workload_cluster_2} cluster using kubeconfig: ${workload_cluster_2_config}\n"
source ${script_dir}/setup_metal_lb.sh "${workload_cluster_2_config}" "${prefix}.102.1" "${prefix}.102.100"
printf "\n--- Metal Load Balancer installed in kind-${workload_cluster_2} cluster.\n"

printf "\n--- Clusters ready for nova-scheduler and nova-agent deployments.\n"

# Get IP of a node where Nova APIServer runs and it's exposed on 32222 hardcoded NodePort.
nova_node_ip=$(echo $inspect_kind|jq --arg container_name ${cp_cluster}-control-plane -r '.Containers|map(select(.Name==$container_name))|.[].IPv4Address'|cut -d/ -f1)
printf "\nNova node IP: ${nova_node_ip}\n"

scheduler_image_repo="elotl/nova-scheduler-trial"
agent_image_repo="elotl/nova-agent-trial"
nova_kubeconfig=".nova/nova/nova-kubeconfig"

# Deploy Nova control plane to kind-cp
KUBECONFIG="${cp_cluster_config}" NOVA_NODE_IP=${nova_node_ip} kubectl nova install cp --image-repository "${scheduler_image_repo}" --context kind-${cp_cluster} nova

KUBECONFIG="${workload_cluster_1_config}" kubectl create ns elotl
KUBECONFIG="${workload_cluster_2_config}" kubectl create ns elotl

while ! KUBECONFIG="${HOME}/${nova_kubeconfig}"  kubectl get secret nova-cluster-init-kubeconfig --namespace elotl;
do
  printf "\nWaiting for nova-cluster-init-kubeconfig secret creation\n"
  sleep 5
done

KUBECONFIG="${HOME}/${nova_kubeconfig}" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${workload_cluster_1_config}" kubectl apply -f -
KUBECONFIG="${HOME}/${nova_kubeconfig}" kubectl get secret -n elotl nova-cluster-init-kubeconfig -o yaml | KUBECONFIG="${workload_cluster_2_config}" kubectl apply -f -

# Deploy Nova agent to kind-workload-1 and kind-workload-2
KUBECONFIG="${workload_cluster_1_config}" kubectl nova install agent --image-repository "${agent_image_repo}" --context kind-${workload_cluster_1} kind-${workload_cluster_1}
KUBECONFIG="${workload_cluster_2_config}" kubectl nova install agent --image-repository "${agent_image_repo}" --context kind-${workload_cluster_2} kind-${workload_cluster_2}

if [ "${user_home}" ];
then
  mv ${HOME}/.nova ${user_home}
  chown -R ${SUDO_UID}:${SUDO_GID} ${user_home}/.nova
  chown ${SUDO_UID}:${SUDO_GID} ${cluster_config_prefix}*
  printf "\nDirectory ${HOME}/.nova has been migrated to ${user_home}/.nova\n"
fi

printf "\nTo interact with Nova, run:\n\nexport KUBECONFIG=\${HOME}/${nova_kubeconfig}:${cp_cluster_config}:${workload_cluster_1_config}:${workload_cluster_2_config}\n\nkubectl get clusters --context=nova\n\n"
