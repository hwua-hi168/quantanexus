#!/bin/bash

#helm repo add calico https://gitcode.com/gh_mirrors/cal/calico/raw/branch/master/charts
helm repo add hi168 https://helm.hi168.com/charts
helm repo update

helm upgrade --install calico-tigera-operator hi168/tigera-operator  \
  --namespace kube-system \
  --set bpf=true \
  --set mtu="1450" \  # eBPF模式推荐MTU
  --set calicoNetworkBackend="bpffs" -f values-calico.yaml