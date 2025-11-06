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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查文件是否存在
check_file() {
    if [[ ! -f "$1" ]]; then
        print_error "文件不存在: $1"
        return 1
    fi
    return 0
}

# 检查文件是否可读
check_file_readable() {
    if [[ ! -r "$1" ]]; then
        print_error "文件不可读: $1"
        return 1
    fi
    return 0
}

# 验证bash语法
check_bash_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        return 0
    else
        print_error "语法检查失败: $file"
        bash -n "$file" 2>&1 | head -10
        return 1
    fi
}

# 修复文件结尾，确保每个文件以换行符结束
ensure_trailing_newline() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # 检查文件是否以换行符结束
        if [[ $(tail -c1 "$file" | wc -l) -eq 0 ]]; then
            echo "" >> "$file"
            print_warning "为文件添加结尾换行符: $file"
        fi
    fi
}

# 添加文件到输出，跳过shebang和重复的source行
add_file() {
    local file="$1"
    local skip_shebang="${2:-true}"
    local skip_sources="${3:-true}"
    
    print_info "添加文件: $file"
    
    if ! check_file "$file"; then
        return 1
    fi
    
    if ! check_file_readable "$file"; then
        return 1
    fi
    
    # 确保文件以换行符结束
    ensure_trailing_newline "$file"
    
    # 添加文件注释分隔符
    echo "" >> "$TEMP_FILE"
    echo "# ==================================================" >> "$TEMP_FILE"
    echo "# 文件: $file" >> "$TEMP_FILE"
    echo "# ==================================================" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # 读取文件内容，跳过shebang行和source导入行
    local line_number=0
    local in_comment_block=false
    local prev_line=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        
        # 跳过shebang行
        if [[ "$skip_shebang" == "true" && "$line" =~ ^#!/ ]]; then
            continue
        fi
        
        # 跳过source导入行
        if [[ "$skip_sources" == "true" && "$line" =~ ^[[:space:]]*source[[:space:]]+ ]]; then
            continue
        fi
        
        # 处理注释块
        if [[ "$line" =~ ^\s*$ && "$prev_line" =~ ^\s*$ ]]; then
            # 跳过连续的空行
            continue
        fi
        
        # 处理未闭合的代码块
        if [[ "$line" =~ ^[[:space:]]*then[[:space:]]*$ && "$prev_line" =~ ^[[:space:]]*if[[:space:]] ]]; then
            # 确保if和then在同一文件中
            echo "$line" >> "$TEMP_FILE"
            prev_line="$line"
            continue
        fi
        
        # 处理函数定义
        if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{?[[:space:]]*$ ]]; then
            # 确保函数定义前有空行（除了第一个函数）
            if [[ "$prev_line" != "" && ! "$prev_line" =~ ^[[:space:]]*$ ]]; then
                echo "" >> "$TEMP_FILE"
            fi
        fi
        
        echo "$line" >> "$TEMP_FILE"
        prev_line="$line"
        
    done < "$file"
    
    # 确保文件以空行结束
    echo "" >> "$TEMP_FILE"
    
    print_success "成功添加文件: $file (共 $line_number 行)"
    return 0
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
    echo "          run_kubeasz_setup.sh, install_helm.sh,"
    echo "          run_longhorn.sh, run_cert_manager.sh,"
    echo "          run_prometheus.sh, run_ingress_nginx.sh,"
    echo "          run_harbor.sh, run_gpu_operator.sh,"
    echo "          run_volcano.sh, run_quantanexus_mgr.sh,"
    echo "          run_quantanexus_cs.sh, main.sh"
    echo "=================================================="
    echo ""
}

# 在脚本开始时显示编译信息
# show_build_info

EOF
}

# 验证所有源文件是否存在
validate_source_files() {
    local files=(
        "common.sh" "collect_info.sh" "remote_config.sh" 
        "install_tools.sh" "download_source.sh" 
        "install_kubeasz.sh" "configure_kubeasz.sh" 
        "run_kubeasz_setup.sh" "install_helm.sh"
        "run_longhorn.sh" "run_cert_manager.sh"
        "run_prometheus.sh" "run_ingress_nginx.sh"
        "run_harbor.sh" "run_gpu_operator.sh"
        "run_volcano.sh" "run_quantanexus_mgr.sh"
        "run_quantanexus_cs.sh" "main.sh"
    )
    
    local missing_files=()
    local existing_files=()
    
    # 首先检查所有文件的语法
    print_info "检查源文件语法..."
    local syntax_errors=()
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            if check_bash_syntax "$file"; then
                existing_files+=("$file")
            else
                syntax_errors+=("$file")
            fi
        else
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#syntax_errors[@]} -gt 0 ]]; then
        print_error "以下源文件存在语法错误:"
        for file in "${syntax_errors[@]}"; do
            echo "  - $file"
        done
        echo ""
        return 1
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_warning "以下文件不存在，将被跳过:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo ""
    fi
    
    if [[ ${#existing_files[@]} -eq 0 ]]; then
        print_error "没有找到任何有效的源文件！"
        return 1
    fi
    
    print_success "找到 ${#existing_files[@]} 个语法正确的源文件"
    return 0
}

# 主编译函数
compile_script() {
    print_info "开始编译脚本..."
    
    # 创建文件头部
    create_header
    
    # 按依赖顺序添加文件
    print_info "添加核心模块..."
    add_file "common.sh"
    add_file "collect_info.sh" 
    add_file "remote_config.sh"
    add_file "install_tools.sh"
    add_file "download_source.sh"
    
    print_info "添加kubeasz相关模块..."
    add_file "install_kubeasz.sh"
    add_file "configure_kubeasz.sh"
    add_file "run_kubeasz_setup.sh"
    
    print_info "添加Helm安装模块..."
    add_file "install_helm.sh"
    
    print_info "添加组件安装模块..."
    add_file "run_longhorn.sh"
    add_file "run_cert_manager.sh"
    add_file "run_prometheus.sh"
    add_file "run_ingress_nginx.sh"
    add_file "run_harbor.sh"
    add_file "run_gpu_operator.sh"
    add_file "run_volcano.sh"
    add_file "run_quantanexus_mgr.sh"
    add_file "run_quantanexus_cs.sh"
    
    print_info "添加主控模块..."
    add_file "main.sh"
    
    # 添加执行权限并保存
    chmod +x "$TEMP_FILE"
    
    # 检查输出文件是否已存在
    if [[ -f "$OUTPUT_FILE" ]]; then
        local backup_file="${OUTPUT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "输出文件已存在，创建备份: $backup_file"
        cp "$OUTPUT_FILE" "$backup_file"
    fi
    
    # 复制到输出文件
    cp "$TEMP_FILE" "$OUTPUT_FILE"
    
    # 清理临时文件
    rm -f "$TEMP_FILE"
    
    print_success "编译完成！输出文件: $OUTPUT_FILE"
    
    # 显示文件信息
    echo ""
    echo "文件信息:"
    echo "  - 大小: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo "  - 行数: $(wc -l < "$OUTPUT_FILE")"
    echo "  - 权限: $(ls -l "$OUTPUT_FILE" | cut -d' ' -f1)"
    echo ""
    echo "使用方式:"
    echo "  ./$OUTPUT_FILE [command]"
    echo "  ./$OUTPUT_FILE --help"
    echo ""
    print_info "可以使用 './$OUTPUT_FILE --help' 查看所有可用命令"
}

# 显示使用说明
show_usage() {
    echo "使用说明: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help        显示此帮助信息"
    echo "  -c, --clean       清理编译生成的文件"
    echo "  -v, --verify      验证源文件是否存在"
    echo "  -i, --info        显示编译信息"
    echo "  -f, --force       强制覆盖已存在的输出文件"
    echo ""
    echo "示例:"
    echo "  $0                编译生成 k8s-cluster-tool.sh"
    echo "  $0 --clean        清理编译文件"
    echo "  $0 --verify       验证源文件"
    echo "  $0 --info         显示编译信息"
}

# 显示编译信息
show_build_info() {
    echo "编译脚本信息:"
    echo "  - 输出文件: $OUTPUT_FILE"
    echo "  - 临时文件: $TEMP_FILE"
    echo ""
    echo "支持的源文件:"
    local files=(
        "common.sh" "collect_info.sh" "remote_config.sh" 
        "install_tools.sh" "download_source.sh" 
        "install_kubeasz.sh" "configure_kubeasz.sh" 
        "run_kubeasz_setup.sh" "install_helm.sh"
        "run_longhorn.sh" "run_cert_manager.sh"
        "run_prometheus.sh" "run_ingress_nginx.sh"
        "run_harbor.sh" "run_gpu_operator.sh"
        "run_volcano.sh" "run_quantanexus_mgr.sh"
        "run_quantanexus_cs.sh" "main.sh"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            if check_bash_syntax "$file" 2>/dev/null; then
                echo "  ✓ $file ($(wc -l < "$file") 行)"
            else
                echo "  ✗ $file (语法错误)"
            fi
        else
            echo "  ✗ $file (缺失)"
        fi
    done
}

# 清理函数
cleanup() {
    print_info "清理编译文件..."
    
    local files_to_clean=("$OUTPUT_FILE" "$TEMP_FILE")
    local cleaned_files=()
    
    for file in "${files_to_clean[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            cleaned_files+=("$file")
        fi
    done
    
    # 清理备份文件
    local backup_files=($(ls -1 "${OUTPUT_FILE}.backup."* 2>/dev/null || true))
    if [[ ${#backup_files[@]} -gt 0 ]]; then
        rm -f "${OUTPUT_FILE}.backup."*
        cleaned_files+=("${#backup_files[@]} 个备份文件")
    fi
    
    if [[ ${#cleaned_files[@]} -gt 0 ]]; then
        print_success "清理完成: ${cleaned_files[*]}"
    else
        print_info "没有需要清理的文件"
    fi
}

# 验证编译结果
verify_output() {
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        print_error "输出文件不存在: $OUTPUT_FILE"
        return 1
    fi
    
    print_info "验证编译结果..."
    
    # 检查文件是否可执行
    if [[ ! -x "$OUTPUT_FILE" ]]; then
        print_warning "输出文件不可执行，尝试添加执行权限"
        chmod +x "$OUTPUT_FILE"
    fi
    
    # 检查文件大小
    local file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
    local line_count=$(wc -l < "$OUTPUT_FILE")
    
    echo "  - 文件大小: $file_size"
    echo "  - 代码行数: $line_count"
    
    # 检查shebang
    if ! head -1 "$OUTPUT_FILE" | grep -q "^#!/bin/bash"; then
        print_warning "输出文件缺少正确的shebang"
    else
        echo "  - Shebang: 正常"
    fi
    
    # 详细语法检查
    print_info "执行详细语法检查..."
    local syntax_output=$(mktemp)
    if bash -n "$OUTPUT_FILE" 2>"$syntax_output"; then
        echo "  - 语法检查: 通过"
        print_success "编译验证通过"
        rm -f "$syntax_output"
        return 0
    else
        echo "  - 语法检查: 失败"
        print_error "语法错误信息:"
        # 显示前5个错误
        head -10 "$syntax_output" | while IFS= read -r error_line; do
            echo "    $error_line"
        done
        rm -f "$syntax_output"
        
        # 尝试定位错误位置
        print_info "尝试定位错误位置..."
        local error_line=$(grep -o "line [0-9]*" "$syntax_output" 2>/dev/null | head -1 | grep -o "[0-9]*" || echo "unknown")
        if [[ "$error_line" != "unknown" ]]; then
            print_info "错误可能出现在第 $error_line 行附近:"
            local start=$((error_line > 10 ? error_line - 10 : 1))
            local end=$((error_line + 5))
            sed -n "${start},${end}p" "$OUTPUT_FILE" | cat -n
        fi
        
        return 1
    fi
}

# 主函数
main() {
    local force_compile=false
    
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
        "-i"|"--info")
            show_build_info
            ;;
        "-f"|"--force")
            force_compile=true
            ;;
        "")
            # 继续执行编译
            ;;
        *)
            print_error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
    
    # 如果不是帮助或清理等命令，则执行编译
    if [[ "$1" != "-h" && "$1" != "--help" && "$1" != "-c" && "$1" != "--clean" && "$1" != "-i" && "$1" != "--info" ]]; then
        if [[ "$force_compile" == "false" && -f "$OUTPUT_FILE" ]]; then
            print_warning "输出文件已存在: $OUTPUT_FILE"
            read -p "是否覆盖? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "编译取消"
                exit 0
            fi
        fi
        
        if validate_source_files; then
            compile_script
            if verify_output; then
                print_success "所有步骤完成！"
            else
                print_warning "编译完成但验证失败，请检查输出文件"
                exit 1
            fi
        else
            print_error "源文件验证失败，编译中止"
            exit 1
        fi
    fi
}

# 信号处理
trap 'rm -f "$TEMP_FILE" "$syntax_output" 2>/dev/null; print_error "编译过程被中断"; exit 1' INT TERM

# 执行主函数
main "$@"