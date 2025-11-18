#!/usr/bin/env bash
set -e

# 1. 添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 3. 安装 redis to kube-system 
helm upgrade -i redis-sentinel bitnami/redis \
  --namespace kube-system --create-namespace \
  --version 23.2.12 \
  -f values-sentinel.yaml 

# 4. 观察
kubectl -n redis  get pod,svc

