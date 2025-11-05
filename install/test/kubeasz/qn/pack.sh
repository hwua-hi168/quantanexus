#!/bin/bash

# 编译脚本 - 将多个脚本文件合并成一个独立的可执行文件

set -e

# 输出文件
OUTPUT_FILE="k8s-cluster-tool.sh"

# 临时文件
TEMP_FILE=$(mktemp)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查文件是否存在
check_file() {
    if [[ ! -f "$1" ]]; then
        print_error "文件不存在: $1"
        return 1
    fi
    return 0
}

# 添加文件到输出，跳过shebang和重复的source行
add_file() {
    local file="$1"
    local skip_shebang="${2:-true}"
    
    print_info "添加文件: $file"
    
    if ! check_file "$file"; then
        return 1
    fi
    
    # 添加文件注释分隔符
    echo "" >> "$TEMP_FILE"
    echo "# ==================================================" >> "$TEMP_FILE"
    echo "# 文件: $file" >> "$TEMP_FILE"
    echo "# ==================================================" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # 读取文件内容，跳过shebang行和source导入行
    while IFS= read -r line; do
        # 跳过shebang行
        if [[ "$skip_shebang" == "true" && "$line" =~ ^#!/ ]]; then
            continue
        fi
        
        # 跳过source导入行（针对main.sh）
        if [[ "$file" == "main.sh" && "$line" =~ ^[[:space:]]*source[[:space:]]+ ]]; then
            continue
        fi
        
        # 跳过空行（如果前面已经有空行）
        if [[ -z "$line" && -z "$prev_line" ]]; then
            continue
        fi
        
        echo "$line" >> "$TEMP_FILE"
        prev_line="$line"
    done < "$file"
    
    # 重置prev_line变量
    unset prev_line
}

# 创建输出文件头部
create_header() {
    cat > "$TEMP_FILE" << 'EOF'
#!/bin/bash

# ==================================================
# K8s 高可用集群规划配置工具 - 编译版本
# 由 pack.sh 自动生成
# 包含所有模块的独立可执行文件
# ==================================================

set -e

# 检查是否在容器中运行（kubeasz相关功能需要）
check_environment() {
    if [[ -f "/.dockerenv" ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    return 1
}

# 显示编译信息
show_build_info() {
    echo "=================================================="
    echo "    K8s 高可用集群规划配置工具 (编译版本)"
    echo "=================================================="
    echo "编译时间: $(date)"
    echo "包含模块: common.sh, collect_info.sh, remote_config.sh,"
    echo "          install_tools.sh, download_source.sh,"
    echo "          install_kubeasz.sh, configure_kubeasz.sh,"
    echo "          run_kubeasz_setup.sh, main.sh"
    echo "=================================================="
    echo ""
}

# 在脚本开始时显示编译信息
show_build_info

EOF
}

# 主编译函数
compile_script() {
    print_info "开始编译脚本..."
    
    # 创建文件头部
    create_header
    
    # 按依赖顺序添加文件
    add_file "common.sh"
    add_file "collect_info.sh" 
    add_file "remote_config.sh"
    add_file "install_tools.sh"
    add_file "download_source.sh"
    add_file "install_kubeasz.sh"
    add_file "configure_kubeasz.sh"
    add_file "run_kubeasz_setup.sh"
    add_file "main.sh"
    
    # 确保输出文件可执行
    cp "$TEMP_FILE" "$OUTPUT_FILE"
    chmod +x "$OUTPUT_FILE"
    
    # 清理临时文件
    rm -f "$TEMP_FILE"
    
    print_success "编译完成！输出文件: $OUTPUT_FILE"
    
    # 显示文件信息
    echo ""
    echo "文件信息:"
    echo "  - 大小: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo "  - 行数: $(wc -l < "$OUTPUT_FILE")"
    echo ""
    echo "使用方式:"
    echo "  ./$OUTPUT_FILE [command]"
    echo "  ./$OUTPUT_FILE --help"
}

# 验证所有源文件是否存在
validate_source_files() {
    local files=("common.sh" "collect_info.sh" "remote_config.sh" 
                 "install_tools.sh" "download_source.sh" 
                 "install_kubeasz.sh" "configure_kubeasz.sh" 
                 "run_kubeasz_setup.sh" "main.sh")
    
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "缺少以下源文件: ${missing_files[*]}"
        echo "请确保所有源文件都在当前目录中"
        return 1
    fi
    
    print_success "所有源文件验证通过"
    return 0
}

# 显示使用说明
show_usage() {
    echo "使用说明: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
    echo "  -c, --clean   清理编译生成的文件"
    echo "  -v, --verify  验证源文件是否存在"
    echo ""
    echo "示例:"
    echo "  $0            编译生成 k8s-cluster-tool.sh"
    echo "  $0 --clean    清理编译文件"
    echo "  $0 --verify   验证源文件"
}

# 清理函数
cleanup() {
    print_info "清理编译文件..."
    rm -f "$OUTPUT_FILE" "$TEMP_FILE"
    print_success "清理完成"
}

# 主函数
main() {
    case "${1:-}" in
        "-h"|"--help")
            show_usage
            ;;
        "-c"|"--clean")
            cleanup
            ;;
        "-v"|"--verify")
            validate_source_files
            ;;
        "")
            if validate_source_files; then
                compile_script
            else
                exit 1
            fi
            ;;
        *)
            print_error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
