#!/bin/bash
# import-ca.sh - 在目标集群导入根证书配置

echo "=== 开始在目标集群导入根证书配置 ==="

# 检查 cert-manager 命名空间是否存在
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "创建 cert-manager 命名空间..."
    kubectl create namespace cert-manager
fi

echo "1. 导入根证书 Secret..."
kubectl apply -f root-ca-secret.yaml

echo "2. 导入 ClusterIssuer..."
kubectl apply -f root-ca-issuer.yaml
kubectl apply -f quantanexus-ca-issuer.yaml

echo "3. 导入根证书 Certificate（可选）..."
if [ -f "root-ca-certificate.yaml" ]; then
    kubectl apply -f root-ca-certificate.yaml
fi

echo "4. 验证导入结果..."
echo "检查 Secret:"
kubectl get secret root-ca-secret -n cert-manager

echo "检查 ClusterIssuer:"
kubectl get clusterissuer

echo "检查证书状态:"
kubectl get certificate -n cert-manager 2>/dev/null || echo "Certificate 资源未导入或 cert-manager 未安装"

echo "=== 导入完成 ==="
