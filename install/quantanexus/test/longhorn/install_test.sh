#!/bin/bash

helm repo add longhorn https://charts.longhorn.io

helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.10.0 \
    -f values-test.yaml 
    