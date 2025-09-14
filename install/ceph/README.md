# Ceph Ansible 部署指南

本文档描述了在QuantanNexus环境中，如何使用 Ansible 部署一个功能完整的 Ceph 集群，包括启用 CephFS、RADOS 网关、RBD、Dashboard 等各种特性。

## 功能特性

- 使用 Ansible 自动化部署 Ceph
- 支持 CephFS、RADOS 网关(RGW)、RBD 和 Dashboard
- 兼容 Ceph 16.x 及更高版本（推荐使用 18.0+）
- 支持 NVMe 缓存以提升性能
- 支持全闪存集群配置

## 系统要求

### 软件要求

- Ansible 2.9 或更高版本
- 目标服务器运行 CentOS/RHEL 8+ 或 Ubuntu 20.04+
- 所有节点的 SSH 访问权限
- Ceph Ansible 角色（cephadm 或 ceph-ansible）

### 硬件要求

#### 最低配置

| 节点类型 | 数量 | CPU | 内存 | 存储 |
|----------|------|-----|------|------|
| Monitor | 3 | 2 核 | 4GB | 20GB |
| Manager | 2 | 2 核 | 4GB | 20GB |
| OSD | 3+ | 4 核 | 8GB | 2+ 硬盘 |
| MDS | 1+ | 2 核 | 4GB | 20GB |
| RGW | 1+ | 2 核 | 4GB | 20GB |

#### 推荐配置

1. **全闪存集群**：为了获得最佳性能，为所有 OSD 使用 NVMe 驱动器
2. **混合设置**：使用 NVMe 驱动器作为缓存层，HDD 作为容量层
3. **网络**：建议 OSD 节点使用 10GbE+ 网络

## QuantanNexus 对ceph的版本支持

| Ceph 版本 | 支持状态 | 说明 |
|-----------|----------|------|
| 18.x (Squid) | ✅ 推荐 | 最新功能和改进 |
| 17.x (Quincy) | ✅ 完全支持 | 稳定且经过充分测试 |
| 16.x (Pacific) | ⚠️ 支持 | 遗留支持，某些功能受限 |
| < 16.x | ❌ 不支持 | 不支持的版本 |

## 功能配置说明

### 核心功能

| 功能 | 配置变量 | 默认值 | 说明 |
|------|----------|--------|------|
| CephFS | `cephfs_enabled: true` | 禁用 | 需要 MDS 节点 |
| RADOS 网关 | `radosgw_enabled: true` | 禁用 | 需要 RGW 节点 |
| RBD | `rbd_enabled: true` | 启用 | 默认功能 |
| Dashboard | `dashboard_enabled: true` | 禁用 | 通过 HTTPS 访问 |

### 性能优化

| 功能 | 配置变量 | 默认值 | 说明 |
|------|----------|--------|------|
| NVMe 缓存 | `nvme_cache_enabled: true` | 禁用 | 提升性能 |
| 全闪存 | `all_flash_cluster: true` | 禁用 | 用于高端设置 |

### NVMe 缓存配置

为了提升存储性能，强烈建议使用 NVMe SSD 作为缓存设备：

```yaml
# 全局配置
nvme_cache_enabled: true
nvme_ssd_devices:
  - /dev/nvme0n1

# 节点特定配置
ceph_osd_cache_device: /dev/nvme0n1
```

## 部署流程

### 1. 环境准备

1. 安装 Ansible
2. 克隆 ceph-ansible 仓库
3. 安装所需的 Ansible 角色

### 2. 配置清单文件

创建包含所有节点的 inventory 文件，定义 monitor、manager、osd、mds、rgw 等节点。

### 3. 配置变量

根据需求配置以下变量：
- Ceph 版本
- 各项功能开关
- 硬件设备路径
- 网络配置

### 4. 执行部署

运行 Ansible playbook 完成一键部署。

### 5. 验证安装

检查集群状态、各组件运行情况和功能是否正常启用。

## 最佳实践

### 硬件选择建议

1. **有条件的情况**：部署全闪存集群以获得最佳性能
2. **一般情况**：至少使用 NVMe SSD 作为缓存盘
3. **网络配置**：确保节点间高速网络连接

### 版本选择建议

- **推荐版本**：Ceph 18.0+ (Squid)
- **稳定版本**：Ceph 17.x (Quincy)
- **兼容版本**：Ceph 16.x (Pacific) - 部分功能可能受限

### 安全考虑

- 使用强密码保护 dashboard 和服务
- 启用 SSL/TLS 加密通信
- 限制 SSH 访问权限
- 定期更新 Ceph 版本以获取安全补丁

## 后续维护

### 集群扩展

通过更新 inventory 文件并重新运行 playbook 来添加新节点。

### 版本升级

修改版本配置变量并重新运行 playbook 来升级 Ceph 版本。

### 监控和故障排除

使用内置的监控工具和日志系统来监控集群健康状态并进行故障排除。