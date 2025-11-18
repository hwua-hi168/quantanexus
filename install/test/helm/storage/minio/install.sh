#!/bin/bash 

helm repo add hi168 https://helm.hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install minio hi168/minio \
  --namespace minio  --create-namespace \
  --values values.yaml \
  --version 5.4.0 \
  --timeout 10m