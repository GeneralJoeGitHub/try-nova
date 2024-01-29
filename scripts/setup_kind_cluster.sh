# create workload and Control plane clusters
touch ${cp_cluster_config}
export KUBECONFIG=${cp_cluster_config}

cat <<EOF | kind create cluster --name ${cp_cluster} --config=-
    kind: Cluster
    apiVersion: ${api_version}
    nodes:
    - role: control-plane
      image: ${cp_node_image}
      extraPortMappings:
      - containerPort: ${cp_node_port}
        hostPort: 80
      - containerPort: ${cp_node_port}
        hostPort: 443
EOF

touch ${workload_cluster_1_config}
export KUBECONFIG=${workload_cluster_1_config}

cat <<EOF | kind create cluster --name ${workload_cluster_1} --config=-
    kind: Cluster
    apiVersion: ${api_version}
    nodes:
    - role: control-plane
      image: ${node_image}
EOF

touch ${workload_cluster_2_config}
export KUBECONFIG=${workload_cluster_2_config}

cat <<EOF | kind create cluster --name ${workload_cluster_2} --config=-
    kind: Cluster
    apiVersion: ${api_version}
    nodes:
    - role: control-plane
      image: ${node_image}
EOF
