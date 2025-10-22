# Quantanexus 测试方案

本测试方案用普通的k8s环境使用kubeasz安装k8s，如果现有k8s更好，建议版本k8s1.28以上。


## 测试流程总览

按照以下顺序进行测试：

1. 环境准备阶段
2. 基础设施安装阶段
3. 核心服务安装阶段
4. 验证与健康检查阶段

## 具体安装步骤

### 1. 环境准备阶段

建议准备好2-3台虚拟机（VM），并配置网络连通性。

#### 1.1 国内主流Linux发行版兼容性

Quantanexus完全支持国内主流的Linux发行版，下表列出了经过验证的操作系统版本：

| 操作系统 | 版本 | 支持状态 | 备注 |
|---------|------|---------|------|
| Ubuntu | 20.04 LTS 以上| ✅ 完全支持 | 推荐使用 |
| CentOS | 7.x 以上| ✅ 完全支持 | 需启用EPEL仓库 |
| Red Hat Enterprise Linux | 7.x 以上 | ✅ 完全支持 | 需有效订阅 |
| 龙蜥(Anolis OS) | 8.x 以上| ✅ 完全支持 | 兼容CentOS 8 |
| 统信UOS | Server 20.0 以上| ✅ 完全支持 | 国产操作系统 |
| 麒麟(Kylin) | V10 以上| ✅ 完全支持 | 国产操作系统 |
| openEuler | 20.03 以上 | ✅ 完全支持 | 华为开源发行版 |
| Rocky Linux | 8.x 以上 | ✅ 完全支持 | CentOS替代品 |
| AlmaLinux | 8.x以上| ✅ 完全支持 | RHEL二进制兼容 |

#### 1.2 硬件规格建议

| 节点类型 | CPU | 内存 | 存储 | 网络 |
|---------|-----|------|------|------|
| Master节点 | 4核 | 8GB | 50GB SSD | 1Gbps |
| Worker节点 | 4核以上 | 16GB以上 | 50GB SSD| 1Gbps |

#### 1.3 网络配置要求

- 所有节点之间必须能够通过内网互通

#### 1.4 软件依赖

所有节点必须预装以下软件：
- curl, wget, tar，jq 等基础工具
- Python 3.6 或更高版本
- SSH 服务并允许root登录或sudo权限
- helm 3.0 以上版本  
```bash 
    snap install helm --classic
    snap install jq
    snap install curl
    snap install wget
```


```

### 2. 基础设施安装阶段

使用 `kubeasz` 中的示例配置安装 Kubernetes 集群。（详细安装步骤请查阅kubeasz [官方文档](https://github.com/easzlab/kubeasz)）



### 3. Helm 插件安装阶段

按照以下顺序执行 `test/helm` 目录下各组件的安装脚本：

由于镜像不容易拉取，我们已经制作了Hi168的helm仓库，方便进行拉取和更新


#### 3.1 核心基础架构组件
```bash
# 安装入口控制器ingress-controller

helm repo add hi168 https://hi168.com/charts 
helm repo update

# 安装证书管理器
./test/helm/cert-manager/install-test.sh

# 安装资源指标收集器
./test/helm/metrics-server/install.sh
```

#### 3.2 存储相关组件
```bash
# 安装存储 
./test/helm/local-path-provisioner/install-test.sh
```

#### 3.3 监控和日志组件
```bash
# 安装监控系统
./test/helm/prometheus/install-test.sh

# 安装可视化面板
./test/helm/grafana/install.sh

# 安装日志系统
./test/helm/loki/install-test.sh
```

#### 3.4 应用程序支持组件
```bash
# 安装数据库
./test/helm/mongodb/install-test.sh

# 安装消息队列
./test/helm/rabbitmq/install.sh

# 安装缓存系统
./test/helm/redis/install-test.sh
```

### 4. 核心服务安装阶段

#### 4.1 安装 quantanexus-mgr（主控服务）
```bash
# 执行主控服务安装脚本
./test/helm/quantanexus-mgr/install-test.sh
```

#### 4.2 安装 quantanexus-cluster-service（集群服务）
```bash
# 执行集群服务安装脚本
./test/helm/quantanexus-cluster-service/install-test.sh
```

### 5. 验证与健康检查阶段

```bash
# 检查所有相关 pod 状态
kubectl get pods -n quantanexus-mgr

# 检查服务是否正常启动
kubectl get svc -n quantanexus-cluster-service

# 查看主控服务日志
kubectl logs -f deployment/quantanexus-mgr -n quantanexus-system

# 查看集群服务日志
kubectl logs -f deployment/quantanexus-cluster-service -n quantanexus-system
```

确认所有服务处于 Running 状态，验证服务间通信正常，检查主控服务能否正确管理集群服务。