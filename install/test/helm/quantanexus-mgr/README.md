基于您提供的 values.yaml 文件，我为您生成 Quantanexus-mgr 的 Helm References 文档：

# Quantanexus Cluster Service Helm Chart 配置参考

## 全局配置 (Global)

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `global.service_namespace` | 服务命名空间 | string | `quantanexus-service` |
| `global.domainName` | 域名配置 | string | `qntest002.hi168.com` |
| `global.registry` | 镜像仓库地址 | string | `registry.cn-hangzhou.aliyuncs.com/quantanexus` |
| `global.masterNode` | 主节点名称 | string | `com-calino-master-1` |
| `global.masterNodes` | 主节点列表（逗号分隔） | string | `"com-calino-master-1,com-calino-master-2"` |
| `global.workerNodes` | 工作节点列表 | string | `"com-calino-worker-1"` |
| `global.labelController` | 是否标记控制器 | boolean | `true` |

## Cert Manager 配置

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `certManager.enabled` | 是否启用 Cert Manager | boolean | `true` |
| `certManager.certificateName` | 证书名称 | string | `""` |
| `certManager.issuerName` | 证书颁发者名称 | string | `qn-mgr-selfsigned-ca` |
| `certManager.issuerKind` | 证书颁发者类型 | string | `ClusterIssuer` |
| `certManager.issuerSecret` | 颁发者密钥名称 | string | `qn-selfsigned-ca-tls` |
| `certManager.dnsNames` | DNS 名称列表 | array | `["controller.quantanexus.io", "controller.qntest002.hi168.com"]` |

## Ingress 配置

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `ingress.tlsManual` | 是否手动配置 TLS | boolean | `false` |
| `ingress.tlsSecret.name` | TLS 密钥名称 | string | `abc-tls` |
| `ingress.tlsSecret.certificate` | 证书内容（Base64编码） | string | `certificate-Base64encoded-tLQo=` |
| `ingress.tlsSecret.privateKey` | 私钥内容（Base64编码） | string | `privateKey-Base64encoded-tLQo=` |
| `ingress.tlsCommonSecret.name` | 通用 TLS 密钥名称 | string | `abc-tls-hwua-common-4` |
| `ingress.tlsCommonSecret.certificate` | 通用证书内容 | string | `certificate-common-Base64encoded-tLQo=` |
| `ingress.tlsCommonSecret.privateKey` | 通用私钥内容 | string | `privateKey-common-Base64encoded-tLQo=` |

## PostgreSQL 配置

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `postgresql.enabled` | 是否启用 PostgreSQL | boolean | `true` |
| `postgresql.auth.username` | 数据库用户名 | string | `"quantanexus"` |
| `postgresql.auth.password` | 数据库密码 | string | `"xYyE3lLtdcvmKkhFEcea"` |
| `postgresql.auth.database` | 数据库名称 | string | `quantanexus001` |
| `postgresql.image.registry` | 镜像仓库地址 | string | `registry.cn-hangzhou.aliyuncs.com/quantanexus` |
| `postgresql.image.repository` | 镜像仓库名称 | string | `postgresql` |
| `postgresql.image.tag` | 镜像标签版本 | string | `14.4.0-debian-11-r23` |
| `postgresql.image.pullPolicy` | 镜像拉取策略 | string | `IfNotPresent` |
| `postgresql.primary.persistence.enabled` | 是否启用持久化存储 | boolean | `true` |
| `postgresql.primary.persistence.storageClass` | 存储类名称 | string | `""` |
| `postgresql.primary.persistence.size` | 存储大小 | string | `40Gi` |
| `postgresql.primary.podSecurityContext.enabled` | 是否启用 Pod 安全上下文 | boolean | `true` |
| `postgresql.primary.podSecurityContext.fsGroup` | 文件系统组 ID | integer | `0` |
| `postgresql.primary.containerSecurityContext.enabled` | 是否启用容器安全上下文 | boolean | `true` |
| `postgresql.primary.containerSecurityContext.runAsUser` | 运行用户 ID | integer | `0` |
| `postgresql.primary.hostNetwork` | 是否使用主机网络 | boolean | `true` |
| `postgresql.hostPath.enabled` | 是否使用 hostPath PV | boolean | `false` |
| `postgresql.metrics.enabled` | 是否启用 Prometheus 指标 | boolean | `true` |
| `postgresql.metrics.image.registry` | 指标镜像仓库地址 | string | `registry.cn-hangzhou.aliyuncs.com/quantanexus` |
| `postgresql.metrics.image.repository` | 指标镜像仓库名称 | string | `postgres-exporter` |
| `postgresql.metrics.image.tag` | 指标镜像标签版本 | string | `0.10.1-debian-11-r24` |
| `postgresql.metrics.image.pullPolicy` | 指标镜像拉取策略 | string | `IfNotPresent` |

## Redis 配置

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `redis.auth.password` | Redis 密码（为空则自动生成） | string | `""` |
| `redis.auth._password` | Redis 密码（内部使用） | string | `""` |
| `redis.auth.existingSecret` | 现有 Secret 名称 | string | `""` |
| `redis.auth.secretKeys.passwordKey` | Secret 中的密码键名 | string | `"redis-password"` |
| `redis.path` | Redis 数据路径 | string | `/var/lib/quantanexus/redis-single` |
| `redis.repository` | Redis 镜像仓库名称 | string | `"redis"` |
| `redis.tag` | Redis 镜像标签版本 | string | `"7.2.4"` |
| `redis.imagePullPolicy` | Redis 镜像拉取策略 | string | `"IfNotPresent"` |

## Quantanexus 核心配置

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| `quantanexus.enabled` | 是否启用 Quantanexus | boolean | `true` |
| `quantanexus.replicaCount` | 副本数量 | integer | `1` |
| `quantanexus.config.maxCronThreads` | 最大 Cron 线程数 | integer | `8` |
| `quantanexus.config.workers` | 工作进程数 | integer | `16` |
| `quantanexus.config.moduleImageCenterEnable` | 是否启用镜像中心模块 | boolean | `false` |
| `quantanexus.config.moduleOssManageEnable` | 是否启用 OSS 管理模块 | boolean | `false` |
| `quantanexus.config.moduleCloudLinkEnable` | 是否启用云链接模块 | boolean | `false` |
| `quantanexus.app.repository` | 核心应用镜像仓库名称 | string | `"quantanexus-basic"` |
| `quantanexus.app.tag` | 核心应用镜像标签版本 | string | `"1.0.5"` |
| `quantanexus.app.imagePullPolicy` | 核心应用镜像拉取策略 | string | `"IfNotPresent"` |
| `quantanexus.imagePullSecrets.enabled` | 是否启用镜像拉取密钥 | boolean | `false` |
| `quantanexus.imagePullSecrets.secrets` | 镜像拉取密钥列表 | array | `[{name: "hi168-harbor-secret"}]` |
| `quantanexus.manager.repository` | 管理器镜像仓库名称 | string | `"quantanexus-mgr"` |
| `quantanexus.manager.tag` | 管理器镜像标签版本 | string | `"v8.3.7.12"` |
| `quantanexus.nginx.repository` | Nginx 镜像仓库名称 | string | `"nginx"` |
| `quantanexus.nginx.tag` | Nginx 镜像标签版本 | string | `"reverse"` |
| `quantanexus.nginx.port` | Nginx 服务端口 | integer | `8443` |
| `quantanexus.nginx.frontend.repository` | 前端镜像仓库名称 | string | `"hi168-vue"` |
| `quantanexus.nginx.frontend.tag` | 前端镜像标签版本 | string | `"v8.3.7.qn11"` |
| `quantanexus.nginx.frontend.env.type` | 前端环境类型 | string | `"hi168slot"` |
| `quantanexus.nginx.frontend.env.moduleList` | 前端模块列表 | string | `"basic"` |
| `quantanexus.hostAliases` | 主机别名配置 | array | `[]` |
| `quantanexus.storage.hostPathEnabled` | 是否使用 hostPath 卷 | boolean | `false` |
| `quantanexus.storage.quantanexusData` | Quantanexus 数据路径 | string | `"/var/lib/quantanexus/quantanexus"` |
| `quantanexus.storage.quantanexusMisc` | Quantanexus 杂项路径 | string | `"/var/lib/quantanexus/quantanexus-misc"` |
| `quantanexus.storage.runtime` | 运行时路径 | string | `"/mnt/quantanexus/runtime"` |
| `quantanexus.storage.pvcSizes.runtime` | 运行时 PVC 大小 | string | `30Gi` |
| `quantanexus.storage.pvcSizes.data` | 数据 PVC 大小 | string | `40Gi` |
| `quantanexus.storage.pvcSizes.misc` | 杂项 PVC 大小 | string | `20Gi` |
| `quantanexus.env.home` | 环境变量：主目录 | string | `"/var/lib/quantanexus"` |
| `quantanexus.env.configPath` | 环境变量：配置文件路径 | string | `"/opt/etc/quantanexus/prod.conf"` |
| `quantanexus.env.updateOption` | 环境变量：更新选项 | string | `"-i muk_web_theme,hw_base,hw_frontend -u all"` |
| `quantanexus.env.preStartShell` | 环境变量：启动前脚本 | string | `"/opt/etc/quantanexus/pre-start.sh"` |
| `quantanexus.livenessProbe.path` | 存活探针路径 | string | `"/liveness"` |
| `quantanexus.livenessProbe.port` | 存活探针端口 | integer | `8069` |
| `quantanexus.livenessProbe.initialDelaySeconds` | 存活探针初始延迟 | integer | `300` |
| `quantanexus.livenessProbe.periodSeconds` | 存活探针检查周期 | integer | `5` |
| `quantanexus.livenessProbe.timeoutSeconds` | 存活探针超时时间 | integer | `3` |
| `quantanexus.livenessProbe.failureThreshold` | 存活探针失败阈值 | integer | `3` |

## 配置说明

### 存储配置说明
- `hostPathEnabled: false`：使用 PVC（Longhorn 自动分配存储）
- `hostPathEnabled: true`：使用 hostPath 卷（需要手动配置节点路径）

### 镜像仓库配置
支持多种镜像仓库配置：
- 中国地区：`registry.cn-hangzhou.aliyuncs.com/quantanexus`
- 海外地区：`docker.io/hwua`
- 私有仓库：`harbor.hi168.com/quantanexus`

### 安全配置
- PostgreSQL 使用 root 权限运行（`runAsUser: 0`）
- 支持主机网络模式
- 提供完整的存活探针配置

这个参考文档涵盖了 Quantanexus-mgr Helm Chart 的所有主要配置参数，便于用户理解和自定义部署配置。