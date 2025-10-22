#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add hi168 https://hi168.com/charts 
helm repo update

helm install prometheus hi168/kube-prometheus-stack --namespace prom --create-namespace -f values-prometheus.yaml
