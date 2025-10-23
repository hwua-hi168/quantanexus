# QuantaNexus Cluster Service Helm Chart 配置参数

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| **Chart 元数据** | | | |
| `name` | 应用名称 | string | `quantanexus-cluster-service` |
| `description` | 应用描述 | string | `A Helm chart for deploying quantanexus cluster service on Kubernetes` |
| `version` | 图表版本 | string | `1.0.0` |
| `appVersion` | 应用版本 | string | `"1.0.0"` |
| **全局配置** | | | |
| `global.domainName` | 域名配置 | string | `qntest002.example.com` |
| `global.registry` | 镜像仓库地址 | string | `registry.cn-hangzhou.aliyuncs.com/quantanexus` |
| `global.masterNode` | 主节点名称（已注释） | string | `""` |
| **Cert Manager 配置** | | | |
| `certManager.enabled` | 是否已安装 Cert Manager | boolean | `true` |
| `certManager.issuerName` | 证书颁发者名称 | string | `quantanexus-ca-issuer` |
| `certManager.issuerKind` | 证书颁发者类型 | string | `ClusterIssuer` |
| `certManager.rootCA.enabled` | 是否启用根证书同步 | boolean | `true` |
| `certManager.rootCA.sourceNamespace` | 源证书所在的命名空间 | string | `cert-manager` |
| `certManager.rootCA.sourceSecretName` | 源 Secret 名称 | string | `root-ca-secret` |
| `certManager.rootCA.targetSecretName` | 目标 Secret 名称 | string | `root-ca-secret` |
| `certManager.rootCA.createRBAC` | 是否创建 RBAC 权限 | boolean | `true` |
| `certManager.rootCA.hooks.rbacWeight` | RBAC Helm hook 权重配置 | string | `"-10"` |
| `certManager.rootCA.hooks.jobWeight` | Job Helm hook 权重配置 | string | `"-5"` |
| **Ingress 配置** | | | |
| `ingress.tlsManual` | 是否手动配置 TLS | boolean | `false` |
| `ingress.tlsSecret.name` | TLS 密钥名称 | string | `abc-tls` |
| `ingress.tlsSecret.certificate` | 证书内容（Base64编码） | string | `""` |
| `ingress.tlsSecret.privateKey` | 私钥内容（Base64编码） | string | `""` |
| `ingress.tlsCommonSecret.name` | 通用 TLS 密钥名称 | string | `abc-tls-hwua-common-4` |
| `ingress.tlsCommonSecret.certificate` | 通用证书内容 | string | `""` |
| `ingress.tlsCommonSecret.privateKey` | 通用私钥内容 | string | `""` |
| **实验服务配置** | | | |
| `abcExperimentService.enabled` | 是否启用实验服务 | boolean | `true` |
| `abcExperimentService.replicaCount` | 副本数量 | integer | `1` |
| `abcExperimentService.app.repository` | 镜像仓库名称 | string | `"abc-experiment-service"` |
| `abcExperimentService.app.tag` | 镜像标签版本 | string | `"v1.3.6"` |
| `abcExperimentService.app.imagePullPolicy` | 镜像拉取策略 | string | `"IfNotPresent"` |
| `abcExperimentService.service.port` | 服务暴露端口 | integer | `8075` |
| `abcExperimentService.service.host` | 服务监听地址 | string | `"0.0.0.0"` |
| `abcExperimentService.kubernetes.useServiceAccount` | 是否使用服务账户进行认证 | boolean | `true` |
| `abcExperimentService.kubernetes.configFile` | Kubernetes 配置文件路径 | string | `"/etc/kubernetes/admin.conf"` |
| `abcExperimentService.kubernetes.host` | Kubernetes API 服务器地址 | string | `"https://10.96.0.1:443"` |
| `abcExperimentService.kubernetes.sslCaCert` | SSL CA 证书文件路径 | string | `"/etc/kubernetes/pki/ca.crt"` |
| `abcExperimentService.kubernetes.verifySsl` | 是否验证 SSL 证书 | string | `"False"` |
| `abcExperimentService.kubernetes.token` | 认证令牌（如使用 Token 认证） | string | `""` |
| `abcExperimentService.kubernetes.assertHostname` | 断言的主机名 | string | `"portal"` |
| `abcExperimentService.kubernetes.server` | Kubernetes 服务器地址 | string | `"https://10.96.0.1:443"` |
| `abcExperimentService.kubernetes.caData` | Base64 编码的 CA 证书数据 | string | `""` |
| `abcExperimentService.kubernetes.clientCertData` | Base64 编码的客户端证书数据 | string | `""` |
| `abcExperimentService.kubernetes.clientKeyData` | Base64 编码的客户端密钥数据 | string | `""` |
| `abcExperimentService.docker.baseUrl` | Docker 守护进程连接地址 | string | `"unix:///var/run/docker.sock"` |
| `abcExperimentService.docker.certPath` | Docker 客户端证书路径 | string | `""` |
| `abcExperimentService.docker.keyPath` | Docker 客户端密钥路径 | string | `""` |
| `abcExperimentService.docker.caCertPath` | Docker CA 证书路径 | string | `""` |
| `abcExperimentService.virtVnc.node` | VNC 服务内部域名 | string | `"virtvnc.kubevirt.svc.cluster.local"` |
| `abcExperimentService.virtVnc.port` | VNC 服务端口 | integer | `8001` |
| `abcExperimentService.enableAuth` | 认证系统配置 | boolean | `false` |
| `abcExperimentService.authUrlBase` | 认证服务基础 URL | string | `""` |
| **ABC WebShell 配置** | | | |
| `abcWebShell.enabled` | 是否启用 ABC WebShell 服务 | boolean | `true` |
| `abcWebShell.replicaCount` | 副本数量 | integer | `1` |
| `abcWebShell.image.repository` | 镜像仓库名称 | string | `abc-webshell` |
| `abcWebShell.image.tag` | 镜像标签版本 | string | `v2.2.4.8` |
| `abcWebShell.image.pullPolicy` | 镜像拉取策略 | string | `IfNotPresent` |
| `abcWebShell.serviceAccount.create` | 是否创建服务账户 | boolean | `true` |
| `abcWebShell.serviceAccount.name` | 服务账户名称 | string | `quantanexus-admin` |
| `abcWebShell.nodeSelector` | 节点选择器配置（用于调度到主节点） | object | `{}` |
| `abcWebShell.config.appname` | 应用名称 | string | `abc-webshell` |
| `abcWebShell.config.httpport` | HTTP 服务端口 | integer | `8080` |
| `abcWebShell.config.runmode` | 运行模式（prod-生产环境） | string | `"prod"` |
| `abcWebShell.config.kubeconfig` | Kubernetes 配置文件路径 | string | `""` |
| `abcWebShell.config.beego_pprof` | 是否启用 Beego 性能分析 | boolean | `true` |
| `abcWebShell.config.https` | 是否启用 HTTPS | boolean | `true` |
| `abcWebShell.config.url_prefix` | URL 路径前缀 | string | `""` |
| `abcWebShell.config.enable_demo` | 是否启用演示模式 | boolean | `true` |
| `abcWebShell.config.debug` | 是否启用调试模式 | boolean | `true` |
| `abcWebShell.service.type` | 服务类型（ClusterIP/NodePort/LoadBalancer） | string | `ClusterIP` |
| `abcWebShell.service.port` | 服务端口 | integer | `80` |
| `abcWebShell.service.targetPort` | 容器内目标端口 | integer | `8080` |
| `abcWebShell.ingress.enabled` | 是否启用 Ingress | boolean | `true` |
| `abcWebShell.ingress.className` | Ingress 控制器类型 | string | `nginx` |
| `abcWebShell.ingress.paths` | 路由路径规则 | array | `["/t(/|$)(.*)", "/demo", "/static/css/xterm.css", "/static/css/bootstrap.min.css", "/static/js/index.js", "/static/xml/app.xml", "/static/imgs/favicon.ico"]` |
| `abcWebShell.ingress.annotations` | Ingress 注解配置 | object | `见注解配置` |
| `abcWebShell.ingress.tls.enabled` | 是否启用 TLS 加密 | boolean | `true` |
| `abcWebShell.ingress.tls.secretName` | TLS 密钥名称 | string | `abc-tls` |
| **ABC 上传服务配置** | | | |
| `abcUploader.enabled` | 是否启用 ABC 上传服务 | boolean | `true` |
| `abcUploader.replicaCount` | 副本数量 | integer | `1` |
| `abcUploader.image.repository` | 镜像仓库名称 | string | `abc-uploader` |
| `abcUploader.image.tag` | 镜像标签版本 | string | `v1.0.0` |
| `abcUploader.image.pullPolicy` | 镜像拉取策略 | string | `IfNotPresent` |
| `abcUploader.serviceAccountName` | 服务账户配置（复用 WebShell 的服务账户） | string | `quantanexus-admin` |
| `abcUploader.nodeSelector` | 节点选择器配置 | object | `{ha_node_type: master}` |
| `abcUploader.config.appname` | 应用名称 | string | `abc-uploader` |
| `abcUploader.config.httpport` | HTTP 服务端口 | integer | `8080` |
| `abcUploader.config.runmode` | 运行模式 | string | `"prod"` |
| `abcUploader.config.kubeconfig` | Kubernetes 配置文件 | string | `""` |
| `abcUploader.config.beego_pprof` | 是否启用 Beego 性能分析 | boolean | `true` |
| `abcUploader.config.enable_allow_origin` | 是否允许跨域请求 | boolean | `false` |
| `abcUploader.config.https` | 是否启用 HTTPS | boolean | `false` |
| `abcUploader.config.url_prefix` | URL 路径前缀 | string | `""` |
| `abcUploader.config.enable_demo` | 是否启用演示模式 | boolean | `true` |
| `abcUploader.config.debug` | 是否启用调试模式 | boolean | `true` |
| `abcUploader.config.uploader_home` | 文件上传存储目录 | string | `"/var/abc-uploader/upload"` |
| `abcUploader.config.orm_debug` | 是否启用 ORM 调试日志 | boolean | `false` |
| `abcUploader.config.clean_chunk_duration` | 清理分块文件的间隔时间（小时） | integer | `8` |
| `abcUploader.config.sqlite_db_path` | SQLite 数据库文件路径 | string | `"/var/abc-uploader/datas/abc_uploader.db"` |
| `abcUploader.hostPaths.upload` | 文件上传目录 | string | `"/usr/local/abc-uploader/upload"` |
| `abcUploader.hostPaths.datas` | 数据存储目录 | string | `"/usr/local/abc-uploader/datas"` |
| `abcUploader.hostPaths.upload_david` | David 专用上传目录 | string | `"/usr/local/abc-uploader/upload-david"` |
| `abcUploader.service.type` | 服务类型 | string | `ClusterIP` |
| `abcUploader.service.port` | 服务端口 | integer | `80` |
| `abcUploader.service.targetPort` | 容器内目标端口 | integer | `8080` |
| `abcUploader.ingress.enabled` | 是否启用 Ingress | boolean | `true` |
| `abcUploader.ingress.className` | Ingress 控制器类型 | string | `nginx` |
| `abcUploader.ingress.paths` | 路由路径规则 | array | `["/file/upload"]` |
| `abcUploader.ingress.annotations` | Ingress 注解配置 | object | `见注解配置` |
| `abcUploader.ingress.tls.enabled` | 是否启用 TLS | boolean | `true` |
| `abcUploader.ingress.tls.secretName` | TLS 密钥名称 | string | `abc-tls` |
| **HWUA 节点服务配置** | | | |
| `hwuaNodeService.enabled` | 是否启用 HWUA 节点服务 | boolean | `true` |
| `hwuaNodeService.image.repository` | 镜像仓库名称 | string | `hwua-node-service` |
| `hwuaNodeService.image.tag` | 镜像标签版本 | string | `0.0.4` |
| `hwuaNodeService.image.pullPolicy` | 镜像拉取策略 | string | `IfNotPresent` |
| `hwuaNodeService.config.appname` | 应用名称 | string | `"HWNodeService"` |
| `hwuaNodeService.config.logfile` | 日志文件路径 | string | `"/var/log/hwua-node-service/service.log"` |
| `hwuaNodeService.config.cri.type` | CRI 类型（containerd/docker） | string | `"containerd"` |
| `hwuaNodeService.config.cri.socket_addr` | CRI Socket 文件路径 | string | `"/run/containerd/containerd.sock"` |
| `hwuaNodeService.config.cri.namespace` | CRI 命名空间 | string | `"k8s.io"` |
| `hwuaNodeService.config.server.ip` | 服务监听 IP | string | `"0.0.0.0"` |
| `hwuaNodeService.config.server.port` | 服务监听端口 | integer | `168` |
| `hwuaNodeService.hostAliases` | 主机别名配置（用于内部 DNS 解析） | array | `[]` |

## Ingress 注解配置详情

**ABC WebShell Ingress 注解：**
```yaml
ingress.kubernetes.io/ingress.class: "nginx"
nginx.org/client-max-body-size: "100M"
nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
nginx.ingress.kubernetes.io/affinity: "cookie"
nginx.ingress.kubernetes.io/session-cookie-name: "session_id"
```

**ABC Uploader Ingress 注解：**
```yaml
ingress.kubernetes.io/ingress.class: "nginx"
nginx.org/client-max-body-size: "100M"
nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
nginx.ingress.kubernetes.io/affinity: "cookie"
nginx.ingress.kubernetes.io/session-cookie-name: "session_id"
```

现在表格包含了完整的四个字段：Key、Description、Type 和 Default。Type 字段根据值的格式推断，Default 字段直接从 values.yaml 中提取。