helm repo add hi168 https://hi168.com/charts 
helm repo update

helm upgrade --install ingress-nginx hi168/ingress-nginx --version 4.0.18 ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f values.yaml 