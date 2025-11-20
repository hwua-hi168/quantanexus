#!/bin/bash

#helm repo add flannel https://flannel-io.github.io/flannel/
helm repo add hi168 https://helm.hi168.com/charts
helm repo update

helm install flannel \
  --namespace kube-flannel \
  --create-namespace \
  --set podCidr="10.244.0.0/16" \
  hi168/flannel -f values.yaml