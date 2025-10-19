helm repo add multus-cni https://helm.projects.multus.io
helm repo update

helm install multus multus-cni/multus-cni
