# Quantanexus

Quantanexus 是一个 Kubernetes 管理应用发行版，专注于为运行容器化工作负载提供强大的基础设施。它包含了预配置的网络插件和企业级部署所需的基本组件。本文用来够建k8s的底层基础设施。

## 功能特性

- **多 CNI 支持**：可选择以下流行的网络解决方案：
  - `flannel`
  - `kubeovn`
  - `cilium`
  - `calico`
- **BGP 支持**：为支持 BGP 的 CNI 插件提供增强的网络功能
- **虚拟化就绪**：默认安装 `kubevirt`，支持在容器旁边运行虚拟机
- **私有镜像仓库**：默认使用 `https://h.hi168.com` 作为容器镜像仓库

## Kubernetes 版本支持

下表显示了 Quantanexus 的 Kubernetes 版本支持矩阵：

| Kubernetes 版本 | 支持状态 | 说明 |
|----------------|---------|------|
| 1.28.x | ✅ 完全支持 | 推荐版本 |
| 1.29.x | ✅ 完全支持 | 推荐版本 |
| 1.30.x | ✅ 完全支持 | 推荐版本 |
| 1.27.x | ✅ 完全支持 | 全面测试和支持 |
| 1.26.x | ⚠️ 有限支持 | 某些功能可能不可用 |
| < 1.26 | ❌ 不支持 | 不支持的版本 |

## 快速开始

### 前提条件

- Kubernetes 集群（建议 v1.28+ 以获得完整功能支持）
- 已配置 kubectl 访问集群
- Helm 3.x（用于某些组件）

### 安装

1. 克隆此仓库：
```bash
git clone <repository-url>
cd quantanexus
```

2. 在 `values.yaml` 中或通过命令行配置您喜欢的 CNI 插件：
```bash
# 使用 Cilium 安装的示例
helm install quantanexus . --set cni.plugin=cilium
```

3. 应用清单文件：
```bash
kubectl apply -f manifests/
```

### 配置选项

| 参数 | 描述 | 默认值 |
|------|------|-------|
| `cni.plugin` | 要使用的 CNI 插件 (flannel, kubeovn, cilium, calico) | `cilium` |
| `network.bgp.enabled` | 启用 BGP 网络 | `false` |
| `kubevirt.enabled` | 启用 KubeVirt 虚拟化 | `true` |
| `registry.url` | 默认容器镜像仓库 | `https://h.hi168.com` |

## 网络

Quantanexus 支持多种 CNI 插件，以满足不同的网络需求：

- **Flannel**：简单的覆盖网络
- **Kube-OVN**：具有子网管理功能的富特性网络
- **Cilium**：基于 eBPF 的网络和安全
- **Calico**：策略驱动的网络

要启用 BGP 功能，请在使用兼容的 CNI 插件时设置 `network.bgp.enabled=true`。

## 虚拟化

默认包含 KubeVirt，允许您将虚拟机作为 Kubernetes 工作负载运行。这使得容器和虚拟机混合部署成为可能。

## 镜像仓库

所有镜像默认从 `https://h.hi168.com` 私有镜像仓库拉取。您可以在部署配置中自定义此设置。

## 贡献

1. Fork 此仓库
2. 创建您的功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 发起 Pull Request

## 许可证

本项目采用 Apache License 2.0 许可证 - 详情请见 [LICENSE](LICENSE) 文件。

## 支持

如有问题和功能请求，请在 GitHub 仓库中提交 issue。