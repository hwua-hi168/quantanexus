#! /bin/bash

PWD="$( cd "$( dirname "$0"  )" && pwd  )"
echo "当前脚本目录：${PWD}"
cd "${PWD}" || exit 1

PROMETHEUS_HOME=$PWD
cd "${PROMETHEUS_HOME}" || exit 1

kubectl apply -f ./namespace.yaml
kubectl apply -f ./node_exporter/deployment/node-exporter-deploy.yaml
kubectl apply -f ./node_exporter/other/
kubectl apply -f ./prometheus/deployment/prometheus-deploy.yaml
kubectl apply -f ./prometheus/other/
kubectl apply -f ./kube-state-metrics/deployment/kube-state-metrics-deploy.yaml
kubectl apply -f ./kube-state-metrics/other/

cd /etc/kubernetes/pki/ || exit
(umask 077; openssl genrsa -out serving.key 2048)
openssl req -new -key serving.key -out serving.csr -subj "/CN=serving"
openssl x509 -req -in serving.csr -CA ./ca.crt -CAkey ./ca.key -CAcreateserial -out serving.crt -days 3650
kubectl create secret generic cm-adapter-serving-certs --from-file=serving.crt=./serving.crt --from-file=serving.key -n prom

cd $PROMETHEUS_HOME || exit
kubectl apply -f ./k8s-prometheus-adapter/deployment/custom-metrics-apiserver-deploy.yaml
kubectl apply -f ./k8s-prometheus-adapter/other/
echo "Successfully installed prometheus..."

# install pushgateway
kubectl apply -f ./pushgateway/deployment/pushgateway-deploy.yaml 
kubectl apply -f ./pushgateway/other/
echo "Successfully installed pushgateway..."

# install grafana
kubectl apply -f  ./hwua-grafana.yaml
echo "Successfully installed grafana..."

kubectl apply -f  ./prom_ingress.yaml
echo "Successfully installed prom_ingress..."
