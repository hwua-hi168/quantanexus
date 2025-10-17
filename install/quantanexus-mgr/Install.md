### 安装Chart

1. 添加必要的仓库:
```bash
helm repo add quantanexus https://helm.hi168.com/charts/
helm repo update
```

3. 安装Chart(示例):
```bash
helm install quantanexus quantanexus/quantanexus-mgr --version 1.0.0 \
    --namespace quantanexus --create-namespace \
    --set domainName=qntest002.hi168.com \
    --set masterNode=com-calino-master-1 \
    --set masterNodes="com-calino-master-1,com-calino-master-2" \
    --set workerNodes="com-calino-worker-1" 
```

### 自定义配置

helm show values quantanexus/quantanexus-mgr > quantanexus-mgr-values.yaml

编辑自定义values文件 quantanexus-mgr-values.yaml

然后 

helm install quantanexus quantanexus/quantanexus-mgr --version 1.0.0 \
    --namespace quantanexus --create-namespace
    -f quantanexus-mgr-values.yaml

### 升级和卸载

```bash
# 升级
helm upgrade quantanexus quantanexus/quantanexus-mgr --version 1.0.0 \
    --namespace quantanexus --create-namespace \
    --set domainName=qntest002.hi168.com \
    --set masterNode=com-calino-master-1 \
    --set masterNodes="com-calino-master-1,com-calino-master-2" \
    --set workerNodes="com-calino-worker-1" 

# 卸载
helm uninstall quantanexus -n abc-platform
```

