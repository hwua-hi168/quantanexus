#!/bin/bash

# 添加官方仓库（如果未添加）
# helm repo add harbor https://helm.goharbor.io
helm repo add hi168 https://helm.hi168.com/charts 
helm repo update

# 安装Harbor，同时应用自定义Job和配置
helm upgrade --install harbor hi168/harbor \
  --namespace harbor \
  --create-namespace \
  -f values.yaml