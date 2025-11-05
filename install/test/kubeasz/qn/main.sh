#!/bin/bash

# 主控程序 - K8s集群配置工具

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入公共函数和变量
source "$SCRIPT_DIR/common.sh"

# 导入其他模块
source "$SCRIPT_DIR/collect_info.sh"
source "$SCRIPT_DIR/remote_config.sh"
source "$SCRIPT_DIR/install_tools.sh"
source "$SCRIPT_DIR/download_source.sh"
source "$SCRIPT_DIR/install_kubeasz.sh"
source "$SCRIPT_DIR/configure_kubeasz.sh"
source "$SCRIPT_DIR/install_helm.sh"

# 显示使用说明
show_usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  collect      收集节点信息和认证信息"
    echo "  ssh          配置SSH免密登录"
    echo "  hostname     配置主机名"
    echo "  download     下载Quantanexus源码"
    echo "  kubeasz      安装kubeasz并创建集群实例"
    echo "  configure    配置kubeasz（hosts文件和自定义代码）"
    echo "  setup        分步执行kubeasz安装"
    echo "  setup-step   执行指定的kubeasz安装步骤"
    echo "  status       检查集群状态"
    echo "  info         显示集群信息"
    echo "  helm         安装Helm"
    echo "  all          执行所有步骤（默认）"
    echo "  show         显示当前配置"
    echo "  generate     生成hosts文件"
    echo ""
    echo "选项:"
    echo "  -h, --help   显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 collect              # 仅收集信息"
    echo "  $0 ssh                  # 仅配置SSH"
    echo "  $0 hostname             # 仅配置主机名"
    echo "  $0 download             # 仅下载源码"
    echo "  $0 kubeasz              # 仅安装kubeasz"
    echo "  $0 configure            # 仅配置kubeasz"
    echo "  $0 setup               # 分步执行kubeasz安装"
    echo "  $0 setup-step 01       # 执行第01步安装"
    echo "  $0 status              # 检查集群状态"
    echo "  $0 info                # 显示集群信息"
    echo "  $0 helm                # 安装Helm"
    echo "  $0 all                 # 执行完整流程"
    echo "  $0 show                # 显示当前配置"
    echo "  $0 generate            # 生成hosts文件"
}

# 检查配置文件是否存在
check_config_file() {
    if [[ ! -f "$SCRIPT_DIR/.k8s_cluster_config" ]]; then
        print_error "配置文件不存在，请先运行 '$0 collect' 收集配置信息"
        return 1
    fi
    return 0
}

# 加载配置文件
load_config() {
    if [[ -f "$SCRIPT_DIR/.k8s_cluster_config" ]]; then
        source "$SCRIPT_DIR/.k8s_cluster_config"
        # 恢复数组变量
        all_ips=($all_ips_str)
        etcd_ips=($etcd_ips_str)
        master_ips=($master_ips_str)
        worker_ips=($worker_ips_str)
        
        # 恢复节点名称映射
        declare -gA node_names
        for mapping in $node_names_mappings; do
            IFS=':' read -r ip name <<< "$mapping"
            node_names["$ip"]="$name"
        done
        
        return 0
    else
        return 1
    fi
}

# 保存配置文件
save_config() {
    # 将数组转换为字符串
    all_ips_str="${all_ips[@]}"
    etcd_ips_str="${etcd_ips[@]}"
    master_ips_str="${master_ips[@]}"
    worker_ips_str="${worker_ips[@]}"
    
    # 将节点名称映射转换为字符串
    node_names_mappings=""
    for ip in "${!node_names[@]}"; do
        node_names_mappings+="$ip:${node_names[$ip]} "
    done
    
    cat > "$SCRIPT_DIR/.k8s_cluster_config" << EOF
# K8s集群配置 - 自动生成，请勿手动修改
all_ips_str="$all_ips_str"
etcd_ips_str="$etcd_ips_str"
master_ips_str="$master_ips_str"
worker_ips_str="$worker_ips_str"
QN_DOMAIN="$QN_DOMAIN"
username="$username"
password="$password"
use_password_auth="$use_password_auth"
node_names_mappings="$node_names_mappings"
EOF
    
    print_success "配置已保存到 $SCRIPT_DIR/.k8s_cluster_config"
}

# 收集信息命令
cmd_collect() {
    print_banner
    configure_nodes
    collect_auth_info
    save_config
    show_config_summary
}

# 配置SSH命令
cmd_ssh() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    if ! install_required_commands; then
        print_error "必需工具安装失败"
        exit 1
    fi
    
    if $use_password_auth; then
        if [[ -z "$password" ]]; then
            echo -n "密码: "
            read -s password
            echo ""
        fi
        
        if ! configure_ssh_access; then
            print_error "SSH配置失败"
            exit 1
        fi
    else
        print_info "使用现有SSH密钥，跳过密码认证配置"
    fi
}

# 配置主机名命令
cmd_hostname() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    if ! install_required_commands; then
        print_error "必需工具安装失败"
        exit 1
    fi
    
    if ! configure_hostnames; then
        print_error "主机名配置失败"
        exit 1
    fi
}

# 显示配置命令
cmd_show() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    show_config_summary
}

# 生成hosts文件命令
cmd_generate() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    generate_hosts_file
}

# 下载源码命令
cmd_download() {
    print_banner
    if ! download_source_code; then
        print_error "源码下载失败"
        return 1
    fi
    print_success "源码下载完成"
}

# 安装kubeasz命令
cmd_kubeasz() {
    print_banner
    if ! install_kubeasz; then
        print_error "kubeasz安装失败"
        return 1
    fi
    
    # 创建默认集群实例
    if ! create_cluster_instance "k8s-qn-01"; then
        print_error "集群实例创建失败"
        return 1
    fi
    
    print_success "kubeasz安装和集群实例创建完成"
}

# 配置kubeasz命令
cmd_configure() {
    print_banner
    if ! configure_kubeasz; then
        print_error "kubeasz配置失败"
        return 1
    fi
    print_success "kubeasz配置完成"
}

# 执行kubeasz分步安装命令
cmd_setup() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_kubeasz_setup "$cluster_name"; then
        print_error "kubeasz分步安装失败"
        return 1
    fi
    
    print_success "kubeasz分步安装完成"
}

# 执行kubeasz指定步骤命令
cmd_setup_step() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="$1"
    local step="$2"
    
    if [[ -z "$cluster_name" || -z "$step" ]]; then
        print_error "缺少参数: 集群名称和步骤编号"
        print_info "用法: $0 setup-step <cluster_name> <step>"
        print_info "示例: $0 setup-step k8s-qn-01 01"
        exit 1
    fi
    
    if ! run_kubeasz_single_step "$cluster_name" "$step"; then
        print_error "kubeasz步骤 $step 安装失败"
        return 1
    fi
    
    print_success "kubeasz步骤 $step 安装完成"
}

# 检查集群状态命令
cmd_status() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! check_cluster_status "$cluster_name"; then
        print_error "集群状态检查失败"
        return 1
    fi
    
    print_success "集群状态检查完成"
}

# 显示集群信息命令
cmd_info() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! show_cluster_info "$cluster_name"; then
        print_error "集群信息显示失败"
        return 1
    fi
    
    print_success "集群信息显示完成"
}

# 安装Helm命令
cmd_helm() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! install_helm "$cluster_name"; then
        print_error "Helm安装失败"
        return 1
    fi
    
    print_success "Helm安装完成"
}

# 主函数
main() {
    print_banner
    
    # 解析命令行参数
    case "${1:-all}" in
        "collect")
            cmd_collect
            ;;
        "ssh")
            check_config_file || exit 1
            load_config
            if ! configure_ssh_access; then
                print_error "SSH免密登录配置失败"
                exit 1
            fi
            ;;
        "hostname")
            check_config_file || exit 1
            load_config
            if ! configure_hostnames; then
                print_error "主机名配置失败"
                exit 1
            fi
            ;;
        "download")
            cmd_download
            ;;
        "kubeasz")
            cmd_kubeasz
            ;;
        "configure")
            check_config_file || exit 1
            load_config
            cmd_configure
            ;;
        "setup")
            check_config_file || exit 1
            load_config
            cmd_setup "${2:-k8s-qn-01}"
            ;;
        "setup-step")
            check_config_file || exit 1
            load_config
            cmd_setup_step "$2" "$3"
            ;;
        "status")
            check_config_file || exit 1
            load_config
            cmd_status "${2:-k8s-qn-01}"
            ;;
        "info")
            check_config_file || exit 1
            load_config
            cmd_info "${2:-k8s-qn-01}"
            ;;
        "helm")
            cmd_helm
            ;;
        "all")
            cmd_collect
            if ! install_required_commands; then
                print_error "必要工具安装失败"
                exit 1
            fi
            if $use_password_auth; then
                if ! configure_ssh_access; then
                    print_error "SSH免密登录配置失败"
                    exit 1
                fi
            fi
            if ! configure_hostnames; then
                print_warning "主机名配置失败，但继续生成配置文件"
            fi
            if ! download_source_code; then
                print_error "源码下载失败"
                exit 1
            fi
            if ! install_kubeasz; then
                print_error "kubeasz安装失败"
                exit 1
            fi
            if ! configure_kubeasz; then
                print_error "kubeasz配置失败"
                exit 1
            fi
            if ! run_kubeasz_setup; then
                print_error "kubeasz分步安装失败"
                exit 1
            fi
            if ! install_helm; then
                print_error "Helm安装失败"
                exit 1
            fi
            print_success "所有配置完成！"
            ;;
        "show")
            check_config_file || exit 1
            load_config
            show_config_summary
            ;;
        "generate")
            check_config_file || exit 1
            load_config
            generate_hosts_file
            ;;
        "-h"|"--help")
            show_usage
            ;;
        *)
            print_error "未知命令: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
