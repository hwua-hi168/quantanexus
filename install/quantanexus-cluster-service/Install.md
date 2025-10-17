### 安装Chart

1. 添加必要的仓库:
```bash
helm repo add quantanexus https://helm.hi168.com/charts/
helm repo update
```

3. 安装Chart(示例):
```bash
helm install quantanexus-service quantanexus/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-service --create-namespace \
    --set domainName=qntest002.hi168.com 
```

### 自定义配置

helm show values quantanexus/quantanexus-cluster-service > quantanexus-cluster-service-values.yaml

编辑自定义values文件 quantanexus-cluster-service-values.yaml

然后 

helm install quantanexus quantanexus/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus --create-namespace
    -f quantanexus-cluster-service-values.yaml

### 升级和卸载

```bash
# 升级
helm upgrade quantanexus-service quantanexus/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-service --create-namespace \
    --set domainName=qntest002.hi168.com 

# 卸载
helm uninstall quantanexus-service -n quantanexus-service
```

