#!/bin/bash
# export-ca.sh - 从源集群导出根证书配置

echo "=== 开始导出根证书配置 ==="

# 创建导出目录
EXPORT_DIR="ca-migration-$(date +%Y%m%d-%H%M%S)"
mkdir -p $EXPORT_DIR
cd $EXPORT_DIR

echo "1. 导出根证书 Secret..."
kubectl get secret root-ca-secret -n cert-manager -o yaml > root-ca-secret.yaml

echo "2. 导出 ClusterIssuer..."
kubectl get clusterissuer root-ca-issuer -o yaml > root-ca-issuer.yaml
kubectl get clusterissuer quantanexus-ca-issuer -o yaml > quantanexus-ca-issuer.yaml

echo "3. 导出根证书 Certificate..."
kubectl get certificate root-ca -n cert-manager -o yaml > root-ca-certificate.yaml

echo "4. 清理 YAML 文件..."
# 运行清理脚本
../clean-yaml.sh

echo "5. 验证导出的文件..."
ls -la *.yaml

echo "=== 导出完成 ==="
echo "导出的文件保存在: $(pwd)"
