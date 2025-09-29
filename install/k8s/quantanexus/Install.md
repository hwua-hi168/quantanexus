### 安装Chart

1. 添加必要的仓库（如果使用子chart）:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

2. 安装依赖:
```bash
helm dependency update quantanexus/
```

3. 安装Chart:
```bash
# 使用ko默认值
helm install release1 ./quantanexus -n abc-platform --create-namespace
```

### 自定义配置

编辑自定义values文件（如./quantanexus/values.yaml）:

然后 
helm upgrade release1 ./quantanexus -n abc-platform


### 升级和卸载

```bash
# 升级
helm upgrade release1 ./abc-platform -n abc-platform

# 卸载
helm uninstall release1 -n abc-platform
```

