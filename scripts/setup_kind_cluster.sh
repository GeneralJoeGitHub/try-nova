# create workload and Control plane clusters

config_template="
kind: Cluster
apiVersion: ${3}
nodes:
  - role: control-plane
    image: ${4}
    extraPortMappings:
    - containerPort: ${5}
      hostPort: 80
    - containerPort: ${5}
      hostPort: 443
"

export KUBECONFIG=${1}
touch ${1}

if [ "${5}" ];
then
  config="${config_template}"
else
  config="${config_template%extraPortMappings:*}"
fi

printf "\n--- ${2} node config:\n${config}\n"
echo "${config}" | kind create cluster --name ${2} --config=-
