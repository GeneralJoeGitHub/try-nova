# Setup Metal Load Balancer for a workload cluster

metal_lb_template='
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - <RANGE_START-RANGE_END>
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
'

KUBECONFIG=$1
metal_lb_config="${metal_lb_template/<RANGE_START-RANGE_END>/$2-$3}"

printf "\n--- Metal LB config:\n\n${metal_lb_config}\n\n"

kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
kubectl patch -n metallb-system deploy controller --type='json' -p '[{"op": "add", "path": "/spec/strategy/rollingUpdate/maxUnavailable", "value": 0}]'
kubectl -n metallb-system wait pod --all --timeout=1200s --for=condition=Ready
kubectl -n metallb-system wait deploy controller --timeout=1200s --for=condition=Available
kubectl -n metallb-system wait apiservice v1beta1.metallb.io --timeout=1200s --for=condition=Available
echo "${metal_lb_config}" | kubectl apply -f -
