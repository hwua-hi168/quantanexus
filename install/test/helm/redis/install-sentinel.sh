#!/usr/bin/env bash
set -e

REPO=bitnami
CHART=redis
VERSION=17.13.2          # 2025-01 验证可用，可按需升级
RELEASE=myredis
NAMESPACE=redis

# 1. 添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 3. 安装
helm upgrade -i redis-sentinel bitnami/redis \
  --namespace redis --create-namespace \
  -f values-sentinel.yaml \
  --wait --timeout 10m

# 4. 观察
kubectl -n redis  get pod,svc
