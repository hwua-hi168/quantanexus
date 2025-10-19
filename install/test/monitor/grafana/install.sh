helm install grafana grafana/grafana \
  -f values.yaml \
  --namespace prom --create-namespace