# Nova - quickstart

This doc covers:
1. The installation guide of Nova.
2. A small Nova tutorial that walks you through the core functionalities of Nova.
3. This is a sandbox environment for trying Nova limited version (up to 10 workloads cluster). If you are interested in using full version, contact Elotl Inc.
4. We love the feedback, so feel free to ask questions by creating an issue in this repo, or joining our Slack [TODO LINK NEEDED]

## Installation on KIND (Kubernetes in Docker) clusters

To setup 3 kind clusters, and install Nova Control Plane + connect two kind clusters as workload clusters, run:

    $ ./scripts/setup_trial_env_on_kind.sh

Once installation finished, you can 

To get more insight into the clusters available resources:
```
$ KUBECONFIG="./scripts/nova-installer-output/nova-kubeconfig" kubectl get clusters -o go-template-file=./scripts/kubectl_templates/cluster_output.gotemplate

  | CLUSTER NAME                  | K8S VERSION | CLOUD PROVIDER | REGION        | STATUS        |
  |----------------------------------------------------------------------------------------------|
  | my-workload-cluster-1         | 1.22        | gce            | us-central1   | ClusterReady  |
  |----------------------------------------------------------------------------------------------|
  |                                              NODES                                           |
  |----------------------------------------------------------------------------------------------|
  | NAME                                                 | AVAILABLE   | AVAILABLE   | AVAILABLE |
  |                                                      | CPU         | MEMORY      | GPU       |
  |                                                                                              |
  | gke-nova-example-agent-1-default-pool-25df6493-263w  | 399m        | 2332068Ki   | 0         |
  | gke-nova-example-agent-1-default-pool-25df6493-f9f8  | 427m        | 2498615680  | 0         |
  |                                                                                              |
  |                      NODES' TAINTS                                                           |
  |                                                                                              |
  |----------------------------------------------------------------------------------------------|



  | CLUSTER NAME                  | K8S VERSION | CLOUD PROVIDER | REGION        | STATUS        |
  |----------------------------------------------------------------------------------------------|
  | my-workload-cluster-2         | 1.22        | gce            | us-central1   | ClusterReady  |
  |----------------------------------------------------------------------------------------------|
  |                                              NODES                                           |
  |----------------------------------------------------------------------------------------------|
  | NAME                                                 | AVAILABLE   | AVAILABLE   | AVAILABLE |
  |                                                      | CPU         | MEMORY      | GPU       |
  |                                                                                              |
  | gke-nova-example-agent-2-default-pool-55fcf389-74zh  | 457m        | 2460060Ki   | 0         |
  | gke-nova-example-agent-2-default-pool-55fcf389-n77s  | 359m        | 2336086400  | 0         |
  | gke-nova-example-agent-2-gpu-pool-950c3823-mlqq      | 677m        | 2354840Ki   | 0         |
  |                                                                                              |
  |                      NODES' TAINTS                                                           |
  |                                                                                              |
  | gke-nova-example-agent-2-gpu-pool-950c3823-mlqq                                              |
  |     - nvidia.com/gpu:present:NoSchedule                                                      |
  |----------------------------------------------------------------------------------------------|

```

## Nova Tutorials / Testing

* [Annotation Based Scheduling](tutorials/poc-annotation-based-scheduling.md)
* [Policy Based Scheduling](tutorials/poc-policy-based-scheduling.md)
* [Smart Scheduling](tutorials/poc-smart-scheduling.md)
* [JIT Standby Workload Cluster](tutorials/poc-standby-workload-cluster.md)

### Supported api-resources

Nova supports the following standard kubernetes objects as well as CRDs:

* configmaps
* namespaces
* pods
* secrets
* serviceaccounts
* services
* daemonsets
* deployments
* replicasets
* statefulsets
* ingressclasses
* ingresses
* networkpolicies
* clusterrolebindings
* clusterroles
* rolebindings
* roles

## Removing Nova trial sandbox

    $ ./scripts/teardown_kind_cluster.sh



