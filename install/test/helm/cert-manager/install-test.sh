#!/bin/bash
# 原仓库，测试原因使用了hi168镜像仓库
# helm repo add jetstack https://charts.jetstack.io
helm repo add hi168 https://hi168.com/charts 
helm repo update
helm upgrade --install cert-manager hi68/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true -f values-cert-manager.yaml