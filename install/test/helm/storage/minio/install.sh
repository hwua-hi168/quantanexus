#!/bin/bash 

helm repo add minio https://charts.min.io
helm repo update

helm upgrade --install minio minio/minio \
  --namespace minio  --create-namespace \
  --values values.yaml \
  --timeout 10m