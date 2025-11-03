#!/bin/bash

# 主控程序 - K8s集群配置工具

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入公共函数和变量
source "$SCRIPT_DIR/common.sh"

# 导入其他模块
source "$SCRIPT_DIR/collect_info.sh"
source "$SCRIPT_DIR/remote_config.sh"

# 显示使用说明
show_usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  collect      收集节点信息和认证信息"
    echo "  ssh          配置SSH免密登录"
    echo "  hostname     配置主机名"
    echo "  all          执行所有步骤（默认）"
    echo "  show         显示当前配置"
    echo "  generate     生成hosts文件"
    echo ""
    echo "选项:"
    echo "  -h, --help   显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 collect        # 仅收集信息"
    echo "  $0 ssh            # 仅配置SSH"
    echo "  $0 hostname       # 仅配置主机名"
    echo "  $0 all            # 执行完整流程"
    echo "  $0 show           # 显示当前配置"
    echo "  $0 generate       # 生成hosts文件"
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
    
    install_required_tools
    
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
    
    install_required_tools
    
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

# 执行所有步骤
cmd_all() {
    print_banner
    
    # 收集信息
    configure_nodes
    collect_auth_info
    save_config
    
    # 安装工具
    install_required_tools
    
    # 配置SSH
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
    
    # 配置主机名
    if ! configure_hostnames; then
        print_warning "主机名配置失败，但继续生成配置文件"
    fi
    
    # 显示结果
    show_config_summary
    generate_hosts_file
    
    print_success "所有配置完成！"
}

# 主函数
main() {
    local command="all"
    
    # 解析命令行参数
    if [[ $# -gt 0 ]]; then
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            collect|ssh|hostname|all|show|generate)
                command="$1"
                ;;
            *)
                print_error "未知命令: $1"
                show_usage
                exit 1
                ;;
        esac
    fi
    
    # 执行对应命令
    case "$command" in
        collect)
            cmd_collect
            ;;
        ssh)
            cmd_ssh
            ;;
        hostname)
            cmd_hostname
            ;;
        all)
            cmd_all
            ;;
        show)
            cmd_show
            ;;
        generate)
            cmd_generate
            ;;
    esac
}

# 执行主函数
main "$@"