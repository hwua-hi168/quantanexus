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
source "$SCRIPT_DIR/run_kubeasz_setup.sh"
source "$SCRIPT_DIR/install_helm.sh"

# 新增组件安装模块
source "$SCRIPT_DIR/run_longhorn.sh"
source "$SCRIPT_DIR/run_cert_manager.sh"
source "$SCRIPT_DIR/run_prometheus.sh"
source "$SCRIPT_DIR/run_ingress_nginx.sh"
source "$SCRIPT_DIR/run_harbor.sh"
source "$SCRIPT_DIR/run_gpu_operator.sh"
source "$SCRIPT_DIR/run_volcano.sh"
source "$SCRIPT_DIR/run_quantanexus_mgr.sh"
source "$SCRIPT_DIR/run_quantanexus_cs.sh"
source "$SCRIPT_DIR/run_uncordon.sh"
source "$SCRIPT_DIR/run_containerd_config.sh"
# 新增MinIO模块
source "$SCRIPT_DIR/run_minio.sh"
# 新增Redis Sentinel模块
source "$SCRIPT_DIR/run_redis_sentinel.sh"
# 新增JuiceFS模块
source "$SCRIPT_DIR/run_juicefs.sh"

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
    echo "  containerd-config   配置containerd镜像仓库"
    echo "  status       检查集群状态"
    echo "  info         显示集群信息"
    echo "  helm         安装Helm"
    echo "  longhorn     安装Longhorn存储"
    echo "  cert-manager 安装Cert-Manager"
    echo "  prometheus   安装Prometheus监控"
    echo "  ingress-nginx 安装Ingress-Nginx"
    echo "  harbor       安装Harbor镜像仓库"
    echo "  gpu-operator 安装GPU Operator"
    echo "  volcano      安装Volcano批处理系统"
    echo "  quantanexus-mgr 安装Quantanexus管理组件"
    echo "  quantanexus-cs 安装Quantanexus计算服务"
    echo "  uncordon     执行节点 uncordon 操作"
    echo "  minio        安装MinIO对象存储"
    echo "  redis-sentinel 安装Redis Sentinel"
    echo "  juicefs      安装JuiceFS存储"
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
    echo "  $0 longhorn            # 安装Longhorn"
    echo "  $0 cert-manager        # 安装Cert-Manager"
    echo "  $0 prometheus          # 安装Prometheus"
    echo "  $0 ingress-nginx       # 安装Ingress-Nginx"
    echo "  $0 harbor              # 安装Harbor"
    echo "  $0 gpu-operator        # 安装GPU Operator"
    echo "  $0 volcano             # 安装Volcano"
    echo "  $0 quantanexus-mgr     # 安装Quantanexus管理组件"
    echo "  $0 quantanexus-cs      # 安装Quantanexus计算服务"
    echo "  $0 uncordon            # 执行节点 uncordon 操作"
    echo "  $0 minio               # 安装MinIO对象存储"
    echo "  $0 redis-sentinel      # 安装Redis Sentinel"
    echo "  $0 juicefs             # 安装JuiceFS存储"
    echo "  $0 all                 # 执行完整流程"
    echo "  $0 show                # 显示当前配置"
    echo "  $0 generate            # 生成hosts文件"
}



# 收集信息命令
cmd_collect() {
    # print_banner
    configure_nodes
    collect_auth_info
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
    
    # 检查默认集群实例是否已存在
    local cluster_name="k8s-qn-01"
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    
    if [[ -d "$cluster_dir" ]]; then
        print_info "集群实例 $cluster_name 已存在，跳过创建"
    else
        # 创建默认集群实例
        if ! create_cluster_instance "$cluster_name"; then
            print_error "集群实例创建失败"
            return 1
        fi
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
    return 0  # 成功执行返回0
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

# 执行Longhorn存储安装命令
cmd_longhorn() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_longhorn_playbook "$cluster_name"; then
        print_error "Longhorn存储安装失败"
        return 1
    fi
    
    print_success "Longhorn存储安装完成"
}

# 执行MinIO对象存储安装命令
cmd_minio() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_minio_playbook "$cluster_name"; then
        print_error "MinIO对象存储安装失败"
        return 1
    fi
    
    print_success "MinIO对象存储安装完成"
}

# 执行Redis Sentinel安装命令
cmd_redis_sentinel() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_redis_sentinel_playbook "$cluster_name"; then
        print_error "Redis Sentinel安装失败"
        return 1
    fi
    
    print_success "Redis Sentinel安装完成"
}

# 执行JuiceFS存储安装命令
cmd_juicefs() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_juicefs_playbook "$cluster_name"; then
        print_error "JuiceFS存储安装失败"
        return 1
    fi
    
    print_success "JuiceFS存储安装完成"
}

# 执行Cert-Manager安装命令
cmd_cert_manager() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_cert_manager_playbook "$cluster_name"; then
        print_error "Cert-Manager安装失败"
        return 1
    fi
    
    print_success "Cert-Manager安装完成"
}

# 执行Prometheus监控安装命令
cmd_prometheus() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_prometheus_playbook "$cluster_name"; then
        print_error "Prometheus监控安装失败"
        return 1
    fi
    
    print_success "Prometheus监控安装完成"
}

# 执行Ingress-Nginx安装命令
cmd_ingress_nginx() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_ingress_nginx_playbook "$cluster_name"; then
        print_error "Ingress-Nginx安装失败"
        return 1
    fi
    
    print_success "Ingress-Nginx安装完成"
}

# 执行Harbor镜像仓库安装命令
cmd_harbor() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_harbor_playbook "$cluster_name"; then
        print_error "Harbor镜像仓库安装失败"
        return 1
    fi
    
    print_success "Harbor镜像仓库安装完成"
}

# 执行GPU Operator安装命令
cmd_gpu_operator() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_gpu_operator_playbook "$cluster_name"; then
        print_error "GPU Operator安装失败"
        return 1
    fi
    
    print_success "GPU Operator安装完成"
}

# 执行Volcano批处理系统安装命令
cmd_volcano() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_volcano_playbook "$cluster_name"; then
        print_error "Volcano批处理系统安装失败"
        return 1
    fi
    
    print_success "Volcano批处理系统安装完成"
}

# 执行Quantanexus管理组件安装命令
cmd_quantanexus_mgr() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_quantanexus_mgr_playbook "$cluster_name"; then
        print_error "Quantanexus管理组件安装失败"
        return 1
    fi
    
    print_success "Quantanexus管理组件安装完成"
}

# 执行Quantanexus计算服务安装命令
cmd_quantanexus_cs() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_quantanexus_cs_playbook "$cluster_name"; then
        print_error "Quantanexus计算服务安装失败"
        return 1
    fi
    
    print_success "Quantanexus计算服务安装完成"
}

# 执行节点 uncordon 命令
cmd_uncordon() {
    print_banner
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! run_uncordon_masters "$cluster_name"; then
        print_error "节点 uncordon 操作失败"
        return 1
    fi
    
    print_success "节点 uncordon 操作完成"
}

# 配置containerd镜像仓库命令
cmd_containerd_config() {
    if ! load_config; then
        print_error "无法加载配置，请先运行 '$0 collect'"
        exit 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! configure_containerd_registry "$cluster_name"; then
        print_error "containerd镜像仓库配置失败"
        return 1
    fi
    
    print_success "containerd镜像仓库配置完成"
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
        "longhorn")
            check_config_file || exit 1
            load_config
            cmd_longhorn "${2:-k8s-qn-01}"
            ;;
        "minio")
            check_config_file || exit 1
            load_config
            cmd_minio "${2:-k8s-qn-01}"
            ;;
        "redis-sentinel")
            check_config_file || exit 1
            load_config
            cmd_redis_sentinel "${2:-k8s-qn-01}"
            ;;
        "juicefs")
            check_config_file || exit 1
            load_config
            cmd_juicefs "${2:-k8s-qn-01}"
            ;;
        "cert-manager")
            check_config_file || exit 1
            load_config
            cmd_cert_manager "${2:-k8s-qn-01}"
            ;;
        "prometheus")
            check_config_file || exit 1
            load_config
            cmd_prometheus "${2:-k8s-qn-01}"
            ;;
        "ingress-nginx")
            check_config_file || exit 1
            load_config
            cmd_ingress_nginx "${2:-k8s-qn-01}"
            ;;
        "harbor")
            check_config_file || exit 1
            load_config
            cmd_harbor "${2:-k8s-qn-01}"
            ;;
        "gpu-operator")
            check_config_file || exit 1
            load_config
            cmd_gpu_operator "${2:-k8s-qn-01}"
            ;;
        "volcano")
            check_config_file || exit 1
            load_config
            cmd_volcano "${2:-k8s-qn-01}"
            ;;
        "quantanexus-mgr")
            check_config_file || exit 1
            load_config
            cmd_quantanexus_mgr "${2:-k8s-qn-01}"
            ;;
        "quantanexus-cs")
            check_config_file || exit 1
            load_config
            cmd_quantanexus_cs "${2:-k8s-qn-01}"
            ;;
        "uncordon")
            check_config_file || exit 1
            load_config
            cmd_uncordon "${2:-k8s-qn-01}"
            ;;
        "containerd-config")
            check_config_file || exit 1
            load_config
            cmd_containerd_config "${2:-k8s-qn-01}"
            ;;
        "all")
            load_config
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
            if ! create_cluster_instance; then
                print_error "kubeasz实例化集群"
                exit 1
            fi
            if ! configure_kubeasz; then
                print_error "kubeasz配置失败"
                exit 1
            fi
            # 检查run_kubeasz_setup是否成功执行（用户未取消）
            if ! cmd_setup; then
                print_error "kubeasz分步安装失败或被用户取消"
                exit 1
            fi
            # 在这里添加 uncordon 操作
            if ! cmd_uncordon; then
                print_error "节点 uncordon 操作失败"
                exit 1
            fi
            if ! run_longhorn_playbook; then
                print_error "Longhorn安装失败"
                exit 1
            fi
            if ! run_minio_playbook; then
                print_error "MinIO安装失败"
                exit 1
            fi
            if ! run_redis_sentinel_playbook; then
                print_error "Redis Sentinel安装失败"
                exit 1
            fi
            if ! run_juicefs_playbook; then
                print_error "JuiceFS安装失败"
                exit 1
            fi
            if ! run_cert_manager_playbook; then
                print_error "Cert-Manager安装失败"
                exit 1
            fi
            if ! run_prometheus_playbook; then
                print_error "Prometheus安装失败"
                exit 1
            fi
            if ! run_ingress_nginx_playbook; then
                print_error "Ingress-Nginx安装失败"
                exit 1
            fi
            if ! run_harbor_playbook; then
                print_error "Harbor安装失败"
                exit 1
            fi
            if ! run_gpu_operator_playbook; then
                print_error "GPU Operator安装失败"
                exit 1
            fi
            if ! run_volcano_playbook; then
                print_error "Volcano安装失败"
                exit 1
            fi
            if ! run_quantanexus_mgr_playbook; then
                print_error "Quantanexus管理组件安装失败"
                exit 1
            fi
            if ! run_quantanexus_cs_playbook; then
                print_error "Quantanexus计算服务安装失败"
                exit 1
            fi
            print_success "所有配置完成！"
            # all动作完成后显示集群信息
            print_info "显示集群配置信息..."
            show_config_summary
            if ! show_cluster_info "k8s-qn-01"; then
                print_error "集群信息显示失败"
                exit 1
            fi
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
