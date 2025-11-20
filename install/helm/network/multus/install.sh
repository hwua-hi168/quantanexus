# helm repo add multus-cni https://helm.projects.multus.io
helm repo add hi168 https://helm.hi168.com/charts
helm repo update

helm install multus hi168/multus-cni
