#!/bin/bash
# clean-yaml.sh - 清理 Kubernetes YAML 文件中的集群特定信息

clean_yaml() {
    local file=$1
    echo "清理文件: $file"
    
    # 删除集群特定字段
    sed -i '/^  resourceVersion:/d' $file
    sed -i '/^  selfLink:/d' $file
    sed -i '/^  uid:/d' $file
    sed -i '/^  creationTimestamp:/d' $file
    sed -i '/^  generation:/d' $file
    sed -i '/^  managedFields:/,/^[^ ]/d' $file
    sed -i '/^status:/,$d' $file  # 删除状态部分
    
    # 对于 Secret，确保 namespace 正确
    if grep -q "kind: Secret" $file; then
        sed -i 's/namespace: [a-zA-Z0-9-]*/namespace: cert-manager/' $file
    fi
}

# 清理所有 YAML 文件
for file in *.yaml; do
    [ -f "$file" ] && clean_yaml "$file"
done

echo "YAML 文件清理完成"
