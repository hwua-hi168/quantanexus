# 安装Chart

本安装文档是为了集群服务quantanexus-cluster-service的安装文档，帮助您快速安装集群服务。

1. 添加必要的仓库:

```bash
helm repo add hi168 https://helm.hi168.com/charts/
helm repo update
```

2. 安装Chart(示例):

```bash
helm install quantanexus-cs hi168/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-cs --create-namespace \
    --set domainName=qntest002.hi168.com 
```

### 自定义配置

helm show values hi168/quantanexus-cluster-service > values.yaml

编辑自定义values文件 values.yaml

然后 

helm install quantanexus hi168/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-cs --create-namespace
    -f values.yaml

### 升级和卸载

```bash
# 升级
helm upgrade quantanexus-cs hi168/quantanexus-cluster-service --version 1.0.0 \
    --namespace quantanexus-cs --create-namespace \
    --set domainName=qntest002.hi168.com 

# 卸载
helm uninstall quantanexus-cs -n quantanexus-service
```

