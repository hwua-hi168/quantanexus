#!/bin/bash
# packer.sh - 将K8s集群配置工具打包成单个文件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查文件是否存在
check_files_exist() {
    local files=(
        "main.sh"
        "common.sh"
        "collect_info.sh"
        "remote_config.sh"
        "install_tools.sh"
        "download_source.sh"
        "install_kubeasz.sh"
        "configure_kubeasz.sh"
        "run_kubeasz_setup.sh"
        "install_helm.sh"
        "run_longhorn.sh"
        "run_cert_manager.sh"
        "run_prometheus.sh"
        "run_ingress_nginx.sh"
        "run_harbor.sh"
        "run_gpu_operator.sh"
        "run_volcano.sh"
        "run_quantanexus_mgr.sh"
        "run_quantanexus_cs.sh"
        "run_uncordon.sh"
        "run_minio.sh"
        "run_redis_sentinel.sh"
        "run_juicefs.sh"
    )
    
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "以下文件缺失:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    print_info "所有必需文件都存在"
    return 0
}

# 提取文件内容（去除shebang和source行）
extract_file_content() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        print_error "文件不存在: $file"
        return 1
    fi
    
    # 使用sed处理文件内容
    sed -E '
        # 删除shebang行
        /^#!/d
        # 删除空行
        /^[[:space:]]*$/d
        # 删除source命令（但保留函数定义和其他内容）
        /^[[:space:]]*source[[:space:]]+.*\.sh/d
        # 删除相对路径的source
        /^[[:space:]]*\.[[:space:]]+.*\.sh/d
    ' "$file"
}

# 创建打包文件
create_packed_file() {
    local output_file="${1:-qni.sh}"
    
    print_info "开始创建打包文件: $output_file"
    
    # 创建文件头部
    cat > "$output_file" << 'EOF'
#!/bin/bash
# K8s集群配置工具 - 打包版本
# 此文件由packer.sh自动生成，包含所有必要的脚本文件

EOF

    print_info "添加公共函数库..."
    echo "" >> "$output_file"
    echo "# ==================== common.sh ====================" >> "$output_file"
    extract_file_content "common.sh" >> "$output_file"
    
    print_info "添加节点信息收集模块..."
    echo "" >> "$output_file"
    echo "# ==================== collect_info.sh ====================" >> "$output_file"
    extract_file_content "collect_info.sh" >> "$output_file"
    
    print_info "添加远程配置模块..."
    echo "" >> "$output_file"
    echo "# ==================== remote_config.sh ====================" >> "$output_file"
    extract_file_content "remote_config.sh" >> "$output_file"
    
    print_info "添加工具安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== install_tools.sh ====================" >> "$output_file"
    extract_file_content "install_tools.sh" >> "$output_file"
    
    print_info "添加源码下载模块..."
    echo "" >> "$output_file"
    echo "# ==================== download_source.sh ====================" >> "$output_file"
    extract_file_content "download_source.sh" >> "$output_file"
    
    print_info "添加kubeasz安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== install_kubeasz.sh ====================" >> "$output_file"
    extract_file_content "install_kubeasz.sh" >> "$output_file"
    
    print_info "添加kubeasz配置模块..."
    echo "" >> "$output_file"
    echo "# ==================== configure_kubeasz.sh ====================" >> "$output_file"
    extract_file_content "configure_kubeasz.sh" >> "$output_file"
    
    print_info "添加kubeasz安装执行模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_kubeasz_setup.sh ====================" >> "$output_file"
    extract_file_content "run_kubeasz_setup.sh" >> "$output_file"
    
    print_info "添加Helm安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== install_helm.sh ====================" >> "$output_file"
    extract_file_content "install_helm.sh" >> "$output_file"
    
    print_info "添加Longhorn安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_longhorn.sh ====================" >> "$output_file"
    extract_file_content "run_longhorn.sh" >> "$output_file"
    
    print_info "添加MinIO安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_minio.sh ====================" >> "$output_file"
    extract_file_content "run_minio.sh" >> "$output_file"
    
    print_info "添加Redis Sentinel安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_redis_sentinel.sh ====================" >> "$output_file"
    extract_file_content "run_redis_sentinel.sh" >> "$output_file"
    
    print_info "添加JuiceFS安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_juicefs.sh ====================" >> "$output_file"
    extract_file_content "run_juicefs.sh" >> "$output_file"
    
    print_info "添加Cert-Manager安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_cert_manager.sh ====================" >> "$output_file"
    extract_file_content "run_cert_manager.sh" >> "$output_file"
    
    print_info "添加Prometheus安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_prometheus.sh ====================" >> "$output_file"
    extract_file_content "run_prometheus.sh" >> "$output_file"
    
    print_info "添加Ingress-Nginx安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_ingress_nginx.sh ====================" >> "$output_file"
    extract_file_content "run_ingress_nginx.sh" >> "$output_file"
    
    print_info "添加Harbor安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_harbor.sh ====================" >> "$output_file"
    extract_file_content "run_harbor.sh" >> "$output_file"
    
    print_info "添加GPU Operator安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_gpu_operator.sh ====================" >> "$output_file"
    extract_file_content "run_gpu_operator.sh" >> "$output_file"
    
    print_info "添加Volcano安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_volcano.sh ====================" >> "$output_file"
    extract_file_content "run_volcano.sh" >> "$output_file"
    
    print_info "添加Quantanexus管理组件安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_quantanexus_mgr.sh ====================" >> "$output_file"
    extract_file_content "run_quantanexus_mgr.sh" >> "$output_file"
    
    print_info "添加Quantanexus计算服务安装模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_quantanexus_cs.sh ====================" >> "$output_file"
    extract_file_content "run_quantanexus_cs.sh" >> "$output_file"
    
    print_info "添加节点uncordon模块..."
    echo "" >> "$output_file"
    echo "# ==================== run_uncordon.sh ====================" >> "$output_file"
    extract_file_content "run_uncordon.sh" >> "$output_file"
    
    print_info "添加主程序..."
    echo "" >> "$output_file"
    echo "# ==================== main.sh ====================" >> "$output_file"
    # 对于main.sh，我们需要特殊处理，保留除source之外的所有内容
    sed -E '
        /^#!/d
        /^[[:space:]]*source[[:space:]]+.*common\.sh/d
        /^[[:space:]]*source[[:space:]]+.*collect_info\.sh/d
        /^[[:space:]]*source[[:space:]]+.*remote_config\.sh/d
        /^[[:space:]]*source[[:space:]]+.*install_tools\.sh/d
        /^[[:space:]]*source[[:space:]]+.*download_source\.sh/d
        /^[[:space:]]*source[[:space:]]+.*install_kubeasz\.sh/d
        /^[[:space:]]*source[[:space:]]+.*configure_kubeasz\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_kubeasz_setup\.sh/d
        /^[[:space:]]*source[[:space:]]+.*install_helm\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_longhorn\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_minio\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_redis_sentinel\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_juicefs\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_cert_manager\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_prometheus\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_ingress_nginx\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_harbor\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_gpu_operator\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_volcano\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_quantanexus_mgr\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_quantanexus_cs\.sh/d
        /^[[:space:]]*source[[:space:]]+.*run_uncordon\.sh/d
    ' main.sh >> "$output_file"
    
    # 添加执行权限
    chmod +x "$output_file"
    
    print_info "打包完成！生成文件: $output_file"
    print_info "文件大小: $(du -h "$output_file" | cut -f1)"
    print_info "行数: $(wc -l < "$output_file")"
}

# 验证打包文件
validate_packed_file() {
    local packed_file="$1"
    
    print_info "验证打包文件..."
    
    # 检查文件是否存在且可执行
    if [[ ! -f "$packed_file" || ! -x "$packed_file" ]]; then
        print_error "打包文件不存在或不可执行"
        return 1
    fi
    
    # 检查是否包含关键函数
    local required_functions=(
        "print_success"
        "print_error"
        "print_info"
        "print_warning"
        "print_banner"
        "show_usage"
        "main"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "$func" "$packed_file"; then
            print_warning "未找到函数: $func"
        fi
    done
    
    # 测试语法检查
    if bash -n "$packed_file"; then
        print_info "语法检查通过"
    else
        print_error "语法检查失败"
        return 1
    fi
    
    print_info "打包文件验证完成"
}

# 显示使用说明
show_usage() {
    echo "用法: $0 [输出文件名]"
    echo ""
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                       # 生成 qni.sh"
    echo "  $0 my_k8s_tool.sh        # 生成指定文件名的打包文件"
    echo ""
    echo "说明:"
    echo "  此脚本将所有的.sh文件打包成一个独立的可执行文件"
}

main() {
    local output_file="${1:-qni.sh}"
    
    # 检查帮助选项
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    print_banner() {
        echo "================================================"
        echo "      K8s集群工具打包脚本"
        echo "================================================"
        echo ""
    }
    
    print_banner
    
    # 检查所有文件是否存在
    if ! check_files_exist; then
        print_error "文件检查失败，请确保所有脚本文件都在当前目录"
        exit 1
    fi
    
    # 创建打包文件
    if create_packed_file "$output_file"; then
        # 验证打包文件
        if validate_packed_file "$output_file"; then
            print_info "打包成功！"
            echo ""
            print_info "使用方法:"
            echo "  ./$output_file --help       # 查看完整帮助"
        else
            print_warning "打包文件验证发现一些问题，但文件已生成"
        fi
    else
        print_error "打包失败"
        exit 1
    fi
}

# 执行主函数
main "$@"