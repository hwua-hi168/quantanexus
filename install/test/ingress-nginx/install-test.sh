helm repo add ingress-nginx https://helm.hi168.com/charts/
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --version 4.0.18 ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f values-test.yaml  