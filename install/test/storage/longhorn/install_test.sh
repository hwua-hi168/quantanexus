#!/bin/bash

# helm repo add longhorn https://charts.longhorn.io
helm repo add hi168 https://hi168.com/charts

helm install longhorn hi168/longhorn --namespace longhorn-system --create-namespace --version 1.10.0 \
    -f values-test.yaml 
    