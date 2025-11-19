helm repo add hi168 https://helm.hi168.com/charts  2>/dev/null
helm repo update

helm upgrade --install ingress-nginx hi168/ingress-nginx --version 4.0.18  \
  -n ingress-nginx --create-namespace \
  --set defaultSettings.volumeEncryption=false \
  -f values.yaml 