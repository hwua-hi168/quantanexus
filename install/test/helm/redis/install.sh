# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm repo update

helm upgrade --install redis-cluster redis-cluster-13.0.4.tgz \
  -n redis-cluster --create-namespace \
  --set password=hwua123456 \
  --set global.security.allowInsecureImages=true \
  -f values.yaml
