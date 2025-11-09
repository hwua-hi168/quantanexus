## 使用说明

一键安装命令行
````bash
curl -sSl [https://d.hi168.com/kct.sh](https://d.hi168.com/kct.sh) -o kct.sh & bash kct.sh
`````

### 安装和使用

1.  **给文件添加执行权限**：

```bash
chmod +x main.sh
```

2.  **查看帮助信息**：

```bash
./main.sh --help
```

### 分步执行命令

1.  **执行完整流程**：

```bash
./main.sh all
# 或者直接运行（默认行为）
./main.sh
```

2.  **集群初始化和配置**：

  * **仅收集配置信息**：
    ```bash
    ./main.sh collect
    ```
  * **仅配置SSH免密登录**：
    ```bash
    ./main.sh ssh
    ```
  * **仅配置主机名**：
    ```bash
    ./main.sh hostname
    ```
  * **仅下载Quantanexus源码**：
    ```bash
    ./main.sh download
    ```
  * **安装kubeasz并创建集群实例**：
    ```bash
    ./main.sh kubeasz
    ```
  * **配置kubeasz（hosts文件和自定义代码）**：
    ```bash
    ./main.sh configure
    ```

3.  **K8s集群安装与状态**：

  * **分步执行kubeasz安装**：
    ```bash
    ./main.sh setup
    ```
  * **执行指定的kubeasz安装步骤**：
    ```bash
    ./main.sh setup-step k8s-qn-01 01
    ```
  * **执行节点 uncordon 操作**：
    ```bash
    ./main.sh uncordon
    ```
  * **检查集群状态**：
    ```bash
    ./main.sh status
    ```
  * **显示集群信息**：
    ```bash
    ./main.sh info
    ```

4.  **K8s组件安装**：

  * **安装Helm**：
    ```bash
    ./main.sh helm
    ```
  * **安装Longhorn存储**：
    ```bash
    ./main.sh longhorn
    ```
  * **安装Cert-Manager**：
    ```bash
    ./main.sh cert-manager
    ```
  * **安装Prometheus监控**：
    ```bash
    ./main.sh prometheus
    ```
  * **安装Ingress-Nginx**：
    ```bash
    ./main.sh ingress-nginx
    ```
  * **安装Harbor镜像仓库**：
    ```bash
    ./main.sh harbor
    ```
  * **安装GPU Operator**：
    ```bash
    ./main.sh gpu-operator
    ```
  * **安装Volcano批处理系统**：
    ```bash
    ./main.sh volcano
    ```

5.  **Quantanexus应用安装**：

  * **安装Quantanexus管理组件**：
    ```bash
    ./main.sh quantanexus-mgr
    ```
  * **安装Quantanexus计算服务**：
    ```bash
    ./main.sh quantanexus-cs
    ```

6.  **辅助命令**：

  * **仅显示当前配置**：
    ```bash
    ./main.sh show
    ```
  * **仅生成hosts文件**：
    ```bash
    ./main.sh generate
    ```

### 特性说明

1.  **配置持久化**：

  - 所有配置信息会保存到 `.k8s_cluster_config` 文件中
  - 后续命令可以读取之前保存的配置

2.  **独立执行**：

  - 每个步骤都可以独立运行
  - 步骤之间有依赖关系检查

3.  **ezctl风格**：

  - 类似kubeasz的ezctl工具的设计
  - 支持分步执行和完整执行
  - 清晰的命令结构和帮助信息

