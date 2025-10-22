#!/bin/bash 
#helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \

helm repo add hi168 https://hi168.com/charts 
helm repo update hi168
# 宿主机已经有驱动了
helm upgrade --install --wait --generate-name  gpu-operator --create-namespace hi168/gpu-operator --set driver.enabled=false -f values.yaml 
#宿主机无驱动
#helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator -f values.yaml 