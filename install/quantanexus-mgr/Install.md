# 安装Chart

1.添加必要的仓库:

```bash
helm repo add hi168 https://helm.hi168.com/charts/
helm repo update
```

2.安装Chart(示例):

```bash
helm install quantanexus hi168/quantanexus-mgr --version 1.0.0 \
  --namespace quantanexus --create-namespace \
  --set global.domainName=qntest002.hi168.com \
  --set global.masterNode=master1 \
  --set "global.masterNodes=master1\,master2" \
  --set global.workerNodes=worker1    
```

## 自定义配置

helm show values quantanexus/quantanexus-mgr > values.yaml

编辑自定义values文件 values.yaml

helm install quantanexus hi68/quantanexus-mgr --version 1.0.0 \
    --namespace quantanexus-mgr --create-namespace
    -f values.yaml

### 升级和卸载

```bash
# 升级
helm upgrade quantanexus hi168/quantanexus-mgr --version 1.0.0 \
    --namespace quantanexus-mgr --create-namespace \
    --set domainName=qntest002.hi168.com \
    --set masterNode=com-calino-master-1 \
    --set masterNodes="com-calino-master-1\,com-calino-master-2" \
    --set workerNodes="com-calino-worker-1" 

# 卸载
helm uninstall quantanexus -n quantanexus
```
