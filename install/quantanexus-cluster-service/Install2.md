### 安装Chart

1. 添加必要的仓库:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

2. 安装依赖:
```bash
helm dependency update quantanexus-cluster-service/
```

3. 安装Chart:
```bash
# 使用ko默认值
helm install release-service-1 ./quantanexus-cluster-service -n quantanexus-service --create-namespace
```

### 自定义配置

编辑自定义values文件（如./quantanexus-cluster-service/values.yaml）:

cp ./quantanexus-cluster-service/values.yaml ./values-quantanexus-cluster-service.yaml

helm install release2 ./quantanexus-cluster-service  -n quantanexus-service --create-namespace  -f ./values-quantanexus-cluster-service.yaml


然后 
helm upgrade release1 ./quantanexus -n abc-platform


### 升级和卸载

```bash
# 升级
helm upgrade release1 ./abc-platform -n abc-platform

helm upgrade ./quantanexus-cluster-service  -n quantanexus-service   -f ./values-quantanexus-cluster-service.yaml

# 卸载
helm uninstall release1 -n quantanexus-service
```

kubectl delete all,ingress,configmap,pvc,secret,sa,role,rolebinding \
  -n quantanexus-service \
  -l app.kubernetes.io/instance=release1

kubectl get all -n quantanexus-service

helm list -n quantanexus-service
kubectl get pods -n quantanexus-service -w