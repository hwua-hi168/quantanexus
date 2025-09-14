#!/bin/bash

##############################################################################################
# 进入当前脚本所在目录
PWD="$( cd "$( dirname "$0"  )" && pwd  )"
echo "当前脚本目录：${PWD}"
cd "${PWD}" || exit 1

##############################################################################################
# 导入配置项
source "./install_config.sh"

echo "start download docker image tar file"

wget https://d.hi168.com/docker/aporeto-k8s-prometheus-adapter-amd64-release-6.26.1.tar
wget https://d.hi168.com/docker/hwua-grafana-v3.tar
wget https://d.hi168.com/docker/k8simages8-kube-state-metrics-amd64-v1.3.1.tar
wget https://d.hi168.com/docker/prom-node-exporter-latest.tar
wget https://d.hi168.com/docker/prom-prometheus-latest.tar
wget https://d.hi168.com/docker/prom-pushgateway-latest.tar
wget https://d.hi168.com/docker/alidns-webhook.tar
wget https://d.hi168.com/docker/cert-manager-cainjector.tar
wget https://d.hi168.com/docker/cert-manager-controller.tar
wget https://d.hi168.com/docker/cert-manager-webhook.tar
wget https://d.hi168.com/docker/ingress-nginx-controller.tar
wget https://d.hi168.com/docker/kube-webhook-certgen.tar

echo "finish download docker image tar file"
