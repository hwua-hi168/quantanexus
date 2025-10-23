# Quantanexus 测试方案

本测试方案适用于在普通 Kubernetes 环境中部署 Quantanexus。推荐使用 kubeasz 安装 Kubernetes 集群，如果已有 Kubernetes 环境，建议版本为 1.28 以上。

## 测试流程总览

按照以下顺序进行测试：

1. 环境准备阶段
2. 基础设施安装阶段
3. 核心服务安装阶段
4. 验证与健康检查阶段

## 具体安装步骤

### 1. 环境准备阶段

建议准备 2-3 台虚拟机（VM），并配置网络连通性。

#### 1.1 国内主流 Linux 发行版兼容性

Quantanexus 完全支持国内主流的 Linux 发行版，下表列出了经过验证的操作系统版本：

| 操作系统 | 版本 | 支持状态 | 备注 |
|---------|------|---------|------|
| Ubuntu | 20.04 LTS 以上 | ✅ 完全支持 | 推荐使用 |
| CentOS | 7.x 以上 | ✅ 完全支持 | 需启用 EPEL 仓库 |
| Red Hat Enterprise Linux | 7.x 以上 | ✅ 完全支持 | 需有效订阅 |
| 龙蜥(Anolis OS) | 8.x 以上 | ✅ 完全支持 | 兼容 CentOS 8 |
| 统信 UOS | Server 20.0 以上 | ✅ 完全支持 | 国产操作系统 |
| 麒麟(Kylin) | V10 以上 | ✅ 完全支持 | 国产操作系统 |
| openEuler | 20.03 以上 | ✅ 完全支持 | 华为开源发行版 |
| Rocky Linux | 8.x 以上 | ✅ 完全支持 | CentOS 替代品 |
| AlmaLinux | 8.x 以上 | ✅ 完全支持 | RHEL 二进制兼容 |

#### 1.2 硬件规格建议

| 节点类型 | CPU | 内存 | 存储 | 网络 |
|---------|-----|------|------|------|
| Master 节点 | 4 核 | 8GB | 50GB SSD | 1Gbps |
| Worker 节点 | 4 核以上 | 16GB 以上 | 50GB SSD | 1Gbps |

#### 1.3 网络配置要求

- 所有节点之间必须能够通过内网互通

#### 1.4 软件依赖

所有节点必须预装以下软件：

- curl, wget, tar, jq 等基础工具
- Python 3.6 或更高版本
- SSH 服务并允许 root 登录或 sudo 权限
- Helm 3.0 以上版本

```bash
snap install helm --classic
snap install jq
snap install curl
snap install wget
```

### 2. 基础设施安装阶段

使用 `kubeasz` 中的示例配置安装 Kubernetes 集群。（详细安装步骤请查阅 kubeasz [官方文档](https://github.com/easzlab/kubeasz)）

### 3. Helm 插件安装阶段

按照以下顺序执行 `test/helm` 目录下各组件的安装脚本：

由于镜像不容易拉取，我们已经制作了 Hi168 的 Helm 仓库，方便进行拉取和更新。测试文件夹下的所有组件都可以通过 Helm mirror 拉取特定版本的 Helm Chart：

```bash
helm repo add hi168 https://helm.hi168.com/charts   
helm repo update hi168
```

#### 3.1 核心基础架构组件

```bash
# 安装证书管理器
# helm repo add jetstack https://charts.jetstack.io  # 正式环境建议使用官方仓库，测试环境使用 hi168 仓库
helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install cert-manager hi168/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true -f ./helm/cert-manager/values-cert-manager.yaml

# 签发证书和 CA
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  secretName: root-ca-secret
  commonName: "QuantaNexus Root CA"
  subject:
    organizations:
      - "HWUA Co.,Ltd."
  duration: 87600h
  renewBefore: 720h
  issuerRef:
    name: root-ca-issuer
    kind: ClusterIssuer
  isCA: true
  usages:
    - digital signature
    - key encipherment
    - cert sign
    - crl sign
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: quantanexus-ca-issuer
spec:
  ca:
    secretName: root-ca-secret
EOF
```

#### 3.2 安装 Ingress Controller

```bash
# helm repo add ingress-nginx https://helm.hi168.com/charts/
# Hi168 Helm repository
helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install ingress-nginx hi168/ingress-nginx --version 4.0.18 \
  -n ingress-nginx --create-namespace \
  -f ./helm/ingress-nginx/values.yaml

# 验证安装，查看所有 Pod 是否正常
kubectl get pods -n ingress-nginx
```

#### 3.3 安装资源指标收集器 Prometheus

```bash
helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install prometheus hi168/kube-prometheus-stack \
  --namespace prom --create-namespace \
  -f ./helm/monitor/kube-prometheus-stack/values.yaml
```

#### 3.4 存储相关组件

安装存储，为了方便测试，默认安装 Longhorn，生产环境强烈建议使用 Ceph：

```bash
# 生产环境请用官方仓库
# helm repo add longhorn https://charts.longhorn.io 

helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

echo "Installing Longhorn..."

helm upgrade --install longhorn hi168/longhorn \
  --namespace longhorn-system --create-namespace \
  --version 1.10.0 -f ./helm/storage/longhorn/values.yaml

# 安装完毕后检查所有 Pod 是否正常
kubectl get pods -n longhorn-system
```

#### 3.5 Harbor 容器镜像仓库

```bash
# 正式环境请使用正式仓库
# helm repo add harbor https://helm.goharbor.io
helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

# 安装 Harbor，同时应用自定义 Job 和配置
helm upgrade --install harbor hi168/harbor \
  --namespace harbor \
  --create-namespace \
  -f ./helm/harbor/values.yaml
```

#### 3.6 GPU Operator 和 Volcano

```bash
# 测试环境请使用 Hi168 的仓库，此处测试英伟达 GPU
# helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo add hi168 https://hi168.com/charts 
helm repo update hi168

# 宿主机已经有驱动了
helm upgrade --install --wait gpu-operator --create-namespace hi168/gpu-operator \
  --set driver.enabled=false -f ./helm/gpu-operator/nvidia-gpu-operator/values.yaml

# 宿主机无驱动
# helm upgrade --install --wait gpu-operator -n gpu-operator --create-namespace nvidia/gpu-operator \
#   -f ./helm/gpu-operator/nvidia-gpu-operator/values.yaml

# 安装 Volcano
# 生产环境请使用官方仓库，此处使用 Hi168 Helm mirror
# helm repo add volcano-sh https://volcano-sh.github.io/helm-charts
helm repo add hi168 https://hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install volcano hi168/volcano \
  -n volcano-system --create-namespace \
  -f ./helm/gpu-operator/volcano/values.yaml
```

### 4. 核心服务安装阶段

#### 4.1 安装 quantanexus-mgr（控制平面）

```bash
# 执行主控服务安装脚本
helm repo add hi168 https://helm.hi168.com/charts/ 2>/dev/null 
helm repo update hi168

helm install quantanexus hi168/quantanexus-mgr --version 1.0.0 \
  --namespace quantanexus-mgr --create-namespace \
  --set global.domainName=qntest002.hi168.com \
  --set global.masterNode=master1 \
  --set "global.masterNodes=master1\,master2" \
  --set global.workerNodes=worker1
```

#### 4.2 安装 quantanexus-cluster-service（集群服务）

```bash
# 执行集群服务安装脚本
helm repo add hi168 https://helm.hi168.com/charts/
helm repo update

helm install quantanexus hi168/quantanexus-mgr --version 1.0.0 \
  --namespace quantanexus --create-namespace \
  --set global.domainName=qntest002.hi168.com \
  --set global.masterNode=master1 \
  --set "global.masterNodes=master1\,master2" \
  --set global.workerNodes=worker1  
  

# 安装 Chart（示例）
helm install quantanexus-cs quantanexus/quantanexus-cluster-service --version 1.0.0 \
  --namespace quantanexus-service --create-namespace \
  --set domainName=qntest002.hi168.com
```

| 组件 | Helm参数文档 |
|------|----------|
| QuantaNexus-Mgr | [Helm参数](./install/test/helm/quantanexus-mgr/README.md) |
| QuantaNexus-CS  | [Helm参数](./install/test/helm/quantanexus-cs/README.md) |

### 5. 验证与健康检查阶段

```bash
# 检查所有相关 Pod 状态
kubectl get pods -n quantanexus-mgr

# 检查服务是否正常启动
kubectl get svc -n quantanexus-cs

# 查看主控服务日志
kubectl logs -f deployment/quantanexus-mgr -n quantanexus-mgr

# 查看集群服务日志
kubectl logs -f deployment/quantanexus-cluster-service -n quantanexus-cs
```

确认所有服务处于 Running 状态，验证服务间通信正常，检查主控服务能否正确管理集群服务。
