#!/bin/bash

helm repo add calico https://gitcode.com/gh_mirrors/cal/calico/raw/branch/master/charts
helm repo update

helm upgrade --install calico calico/calico \
  --namespace kube-system \
  --set bpf=true \
  --set mtu="1450" \  # eBPF模式推荐MTU
  --set calicoNetworkBackend="bpffs"