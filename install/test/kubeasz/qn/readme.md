## 使用说明

### 安装和使用

1. **给所有文件添加执行权限**：
   ```bash
   chmod +x main.sh common.sh collect_info.sh remote_config.sh install_tools.sh download_source.sh install_kubeasz.sh configure_kubeasz.sh
   ```

2. **查看帮助信息**：
   ```bash
   ./main.sh --help
   ```

### 分步执行命令

1. **仅收集配置信息**：
   ```bash
   ./main.sh collect
   ```

2. **仅配置SSH免密登录**：
   ```bash
   ./main.sh ssh
   ```

3. **仅配置主机名**：
   ```bash
   ./main.sh hostname
   ```

4. **仅显示当前配置**：
   ```bash
   ./main.sh show
   ```

5. **仅生成hosts文件**：
   ```bash
   ./main.sh generate
   ```

6. **执行完整流程**：
   ```bash
   ./main.sh all
   # 或者直接运行（默认行为）
   ./main.sh
   ```

### 特性说明

1. **配置持久化**：
   - 所有配置信息会保存到 `.k8s_cluster_config` 文件中
   - 后续命令可以读取之前保存的配置

2. **独立执行**：
   - 每个步骤都可以独立运行
   - 步骤之间有依赖关系检查

3. **ezctl风格**：
   - 类似kubeasz的ezctl工具的设计
   - 支持分步执行和完整执行
   - 清晰的命令结构和帮助信息

这种设计使得工具更加灵活，可以根据需要单独执行某个步骤，也支持完整的自动化部署流程。