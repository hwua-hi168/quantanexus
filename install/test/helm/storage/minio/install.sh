#!/bin/bash 

helm repo add minio https://charts.min.io
helm repo update

helm upgrade --install minio minio/minio \
  --namespace minio  --create-namespace \
  --values values.yaml \
  --version 5.4.0 \
  --timeout 10m