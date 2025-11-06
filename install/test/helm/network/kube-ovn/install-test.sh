#!/bin/bash

# kubectl label node -lbeta.kubernetes.io/os=linux kubernetes.io/os=linux --overwrite
# node/kube-ovn-control-plane not labeled
# node/kube-ovn-worker not labeled

# kubectl label node -lnode-role.kubernetes.io/control-plane kube-ovn/role=master --overwrite
# node/kube-ovn-control-plane labeled

# 以下 label 用于 dpdk 镜像的安装，非 dpdk 情况，可以忽略
# kubectl label node -lovn.kubernetes.io/ovs_dp_type!=userspace ovn.kubernetes.io/ovs_dp_type=kernel --overwrite
# node/kube-ovn-control-plane labeled
# node/kube-ovn-worker labeled

# helm repo add kubeovn https://kubeovn.github.io/kube-ovn/
helm repo add hi168 https://helm.hi168.com/charts
helm repo update kubeovn

helm install kube-ovn hi168/kube-ovn --wait -n kube-system --version v1.14.11 -f values-kube-ovn.yaml