#!/bin/bash

# helm repo add longhorn https://charts.longhorn.io
helm repo add hi168 https://helm.hi168.com/charts 2>/dev/null
helm repo update hi168


echo "Installing Longhorn..."

helm install longhorn hi168/longhorn --namespace longhorn-system --create-namespace --version 1.10.0 \
    -f values.yaml
    