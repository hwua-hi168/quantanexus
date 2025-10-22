#!/bin/bash 

helm repo add hi168 https://helm.hi168.com/charts/ 2>/dev/null
helm repo update hi168


helm upgrade --install quantanexus-cs hi168/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-cs --create-namespace \
    --set domainName=qntest002.hi168.com   -f values.yaml