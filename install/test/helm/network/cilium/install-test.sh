#!/bin/bash 

#helm repo add cilium https://helm.cilium.io/
helm repo add hi168 https://helm.hi168.com/charts/
#local install 
#helm install cilium ./cilium -n kube-system  \

#remote repository install 
helm install cilium hi168/cilium --version 1.18.2 --namespace kube-system 
    --set k8sServiceHost=192.168.0.102 \
    --set k8sServicePort=6443 \
    --version 1.16.1 \
    --set cni.exclusive=false \
    --set ipv4.enabled=true \
    --set debug.enabled=false \
    --set loadBalancer.l7.backend=envoy \
    --set ipam.mode=cluster-pool \
    --set cluster.name=hi168-shanghai1 \
    --set ipv4NativeRoutingCIDR="10.16.0.0/16" \
    --set kubeProxyReplacement=true \
    --set nodePort.enabled=true \
    --set bpf.masquerade=true \
    --set bandwidthManager.enabled=true \
   --set bandwidthManager.bbr=true -f values-cilium.yaml
    


    # 统一网卡  
    # --set devices=hi168-business  
    
    # --set "etcd.endpoints[0]=https://192.168.88.101:2379" \
    # --set "etcd.endpoints[1]=https://192.168.88.102:2379" \
    # --set "etcd.endpoints[2]=https://192.168.88.103:2379"
