#!/usr/bin/env bash
set -e

# 1. 添加仓库
helm repo add hi168 https://helm.hi168.com/charts 2>/dev/null
helm repo update hi168

# 3. 安装 redis to kube-system 
helm upgrade -i redis-sentinel hi168/redis \
  --namespace kube-system --create-namespace \
  --version 23.2.12 \
  -f values-sentinel.yaml 

# 4. 观察
kubectl -n redis  get pod,svc

