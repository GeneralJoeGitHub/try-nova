# Setup Metal Load Balancer for a workload cluster
printf "\n--- Metal LB config:\n\n$(cat $2)\n\n"

KUBECONFIG="$1" kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
KUBECONFIG="$1" kubectl patch -n metallb-system deploy controller --type='json' -p '[{"op": "add", "path": "/spec/strategy/rollingUpdate/maxUnavailable", "value": 0}]'
KUBECONFIG="$1" kubectl -n metallb-system wait pod --all --timeout=1200s --for=condition=Ready
KUBECONFIG="$1" kubectl -n metallb-system wait deploy controller --timeout=1200s --for=condition=Available
KUBECONFIG="$1" kubectl -n metallb-system wait apiservice v1beta1.metallb.io --timeout=1200s --for=condition=Available
KUBECONFIG="$1" kubectl apply -f "$2"
