#!/bin/bash 
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia 
helm repo update
helm upgrade --install --wait gpu-operator ./gpu-operator-v25.3.4.tgz \
     -n gpu-operator --create-namespace \
     -f values-test.yaml \
     --wait --timeout=15m


# kubectl label nodes $NODE nvidia.com/gpu.deploy.operands=false   
