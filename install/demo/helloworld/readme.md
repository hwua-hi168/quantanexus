我来为你创建一个部署在单独命名空间的 Helm Hello World 示例。

## 1. 创建 Helm Chart

```bash
# 创建名为 helloworld 的 chart
helm create helloworld

# 删除自动生成的文件，我们从头创建
rm -rf helloworld/templates/*
```

## 2. 项目结构

```
helloworld/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── configmap.yaml
```

## 3. Chart.yaml

```yaml
apiVersion: v2
name: helloworld
description: A Helm Hello World chart deployed in dedicated namespace
type: application
version: 0.1.0
appVersion: "1.0.0"
```

## 4. values.yaml

```yaml
# 命名空间配置
namespace:
  name: helloworld-ns
  create: true

# 应用配置
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

service:
  type: ClusterIP
  port: 80

app:
  message: "Hello, World from Helm in dedicated namespace!"
  environment: "development"
```

## 5. templates/namespace.yaml

```yaml
{{- if .Values.namespace.create }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace.name }}
  labels:
    name: {{ .Values.namespace.name }}
    app: {{ .Chart.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
```

## 6. templates/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Chart.Name }}-config
  namespace: {{ .Values.namespace.name }}
  labels:
    app: {{ .Chart.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
data:
  message: {{ .Values.app.message | quote }}
  environment: {{ .Values.app.environment | quote }}
  namespace: {{ .Values.namespace.name | quote }}
```

## 7. templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Values.namespace.name }}
  labels:
    app: {{ .Chart.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
        version: {{ .Chart.AppVersion }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          env:
            - name: HELLO_MESSAGE
              valueFrom:
                configMapKeyRef:
                  name: {{ .Chart.Name }}-config
                  key: message
            - name: NAMESPACE
              valueFrom:
                configMapKeyRef:
                  name: {{ .Chart.Name }}-config
                  key: namespace
            - name: ENVIRONMENT
              valueFrom:
                configMapKeyRef:
                  name: {{ .Chart.Name }}-config
                  key: environment
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
```

## 8. templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}-service
  namespace: {{ .Values.namespace.name }}
  labels:
    app: {{ .Chart.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: {{ .Chart.Name }}
```

## 9. 使用 Chart

### 安装到专用命名空间
```bash
# 安装并自动创建命名空间
helm install my-helloworld ./helloworld

# 或者指定发布名称和等待完成
helm install my-helloworld ./helloworld --wait --timeout 5m
```

### 使用自定义命名空间名称
```bash
# 创建自定义 values 文件 custom-namespace.yaml
cat > custom-namespace.yaml << EOF
namespace:
  name: my-custom-namespace
  create: true

replicaCount: 2
app:
  message: "Hello from custom namespace!"
  environment: "production"
EOF

# 使用自定义配置安装
helm install my-release ./helloworld -f custom-namespace.yaml
```

### 使用现有命名空间（不自动创建）
```bash
# 创建 values 文件 existing-namespace.yaml
cat > existing-namespace.yaml << EOF
namespace:
  name: existing-namespace
  create: false  # 不创建命名空间，使用已存在的

replicaCount: 1
app:
  message: "Using existing namespace"
EOF

# 先创建命名空间
kubectl create namespace existing-namespace

# 然后安装
helm install my-release ./helloworld -f existing-namespace.yaml
```

## 10. 管理和验证

### 查看发布状态
```bash
# 查看所有命名空间的 Helm 发布
helm list --all-namespaces

# 查看特定发布状态
helm status my-helloworld -n helloworld-ns

# 查看命名空间
kubectl get namespaces

# 查看特定命名空间中的资源
kubectl get all -n helloworld-ns
```

### 验证部署
```bash
# 检查 Pod 状态
kubectl get pods -n helloworld-ns

# 查看 Pod 详情
kubectl describe pod -l app=helloworld -n helloworld-ns

# 查看 ConfigMap
kubectl get configmap -n helloworld-ns

# 查看 Service
kubectl get service -n helloworld-ns
```

### 测试应用
```bash
# 端口转发到本地测试
kubectl port-forward -n helloworld-ns service/helloworld-service 8080:80 &

# 访问应用
curl http://localhost:8080

# 查看 Pod 日志
kubectl logs -n helloworld-ns -l app=helloworld
```

### 升级和回滚
```bash
# 升级发布
helm upgrade my-helloworld ./helloworld -f updated-values.yaml

# 查看发布历史
helm history my-helloworld

# 回滚到上一个版本
helm rollback my-helloworld

# 回滚到特定版本
helm rollback my-helloworld 2
```

### 卸载
```bash
# 卸载发布但保留命名空间
helm uninstall my-helloworld

# 如果要删除命名空间
kubectl delete namespace helloworld-ns

# 或者使用 Helm 卸载并清理所有资源
helm uninstall my-helloworld && kubectl delete namespace helloworld-ns
```

## 主要特点

1. **独立命名空间**: 所有资源都部署在专用命名空间中
2. **可配置**: 可以通过 values.yaml 轻松配置命名空间名称
3. **可选创建**: 可以选择自动创建命名空间或使用现有命名空间
4. **资源隔离**: 所有资源都在独立命名空间中，便于管理
5. **标签一致**: 所有资源都有统一的标签，便于识别和管理

这样部署可以很好地隔离应用，避免与默认命名空间中的其他资源冲突。