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


# ==================================================
# 文件: common.sh
# ==================================================

# 公共函数和变量定义

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
declare -A node_names
all_ips=()
etcd_ips=()
master_ips=()
worker_ips=()
QN_DOMAIN=""
username=""
password=""
use_password_auth=false

# 用于保存配置的变量
all_ips_str=""
etcd_ips_str=""
master_ips_str=""
worker_ips_str=""
node_names_mappings=""
IMAGE_REGISTRY=""

# 打印带颜色的信息

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_banner() {
    echo "=================================================="
    echo "    K8s 高可用集群规划配置工具"
    echo "=================================================="
    echo ""
}

# IP地址验证函数

validate_ip() {
    local ip=$1
    local stat=1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# 验证IP列表

validate_ip_list() {
    local ips=("$@")
    for ip in "${ips[@]}"; do
        if ! validate_ip "$ip"; then
            print_error "无效的IP地址: $ip"
            return 1
        fi
    done
    return 0
}

# 检查命令是否存在

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "命令 $1 未找到，请先安装"
        return 1
    fi
    return 0
}

# 生成master节点名称

generate_master_node_name() {
    local index=$1
    echo "k8s-master-${index}"
}

# 生成worker节点名称

generate_worker_node_name() {
    local index=$1
    echo "k8s-worker-${index}"
}

# 生成节点名称映射

generate_node_names() {
    # 清空映射
    declare -gA node_names
    
    # 生成master节点名称
    for i in "${!master_ips[@]}"; do
        node_name=$(generate_master_node_name "$((i+1))")
        node_names["${master_ips[i]}"]="$node_name"
    done
    
    # 生成worker节点名称
    for i in "${!worker_ips[@]}"; do
        node_name=$(generate_worker_node_name "$((i+1))")
        node_names["${worker_ips[i]}"]="$node_name"
    done
}

# 通用执行函数，自动处理sudo权限

execute_with_privileges() {
    local command="$*"
    if [[ $EUID -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo $command
    elif [[ $EUID -eq 0 ]]; then
        $command
    else
        print_error "权限不足，请以root用户运行此脚本或确保sudo可用"
        return 1
    fi
}


# ==================================================
# 文件: collect_info.sh
# ==================================================

# 收集用户信息模块

# 配置节点信息

configure_nodes() {
    print_info "本脚本将帮助您配置K8s高可用集群的节点信息"
    echo ""

    # 第1步：获取所有主机IP
    echo "=== 第1步：获取所有主机IP ==="
    print_info "请输入所有K8s集群节点的IP地址（用空格分隔，至少需要3个节点）"
    while true; do
        read -p "请输入所有节点IP: " all_ips_input
        
        # 转换为数组
        all_ips=($all_ips_input)
        
        # 验证IP数量
        if [ ${#all_ips[@]} -lt 3 ]; then
            print_error "错误：至少需要3个节点IP，当前只提供了 ${#all_ips[@]} 个"
            continue
        fi
        
        # 验证IP格式
        if ! validate_ip_list "${all_ips[@]}"; then
            continue
        fi
        
        break
    done

    print_success "成功获取 ${#all_ips[@]} 个节点IP: ${all_ips[*]}"
    echo ""

    # 第2步：配置etcd节点
    echo "=== 第2步：配置etcd节点 ==="
    print_info "etcd集群需要3个节点组成奇数集群"
    print_info "默认使用前3个IP作为etcd节点: ${all_ips[0]}, ${all_ips[1]}, ${all_ips[2]}"
    read -p "是否使用默认etcd节点? (y/n, 默认y): " use_default_etcd

    if [[ $use_default_etcd =~ ^[Nn]$ ]]; then
        while true; do
            echo "当前所有可用IP: ${all_ips[*]}"
            read -p "请手动输入3个etcd节点IP（用空格分隔）: " etcd_ips_input
            etcd_ips=($etcd_ips_input)
            
            if [ ${#etcd_ips[@]} -ne 3 ]; then
                print_error "错误：etcd集群必须正好是3个节点"
                continue
            fi
            
            # 验证IP格式
            if ! validate_ip_list "${etcd_ips[@]}"; then
                continue
            fi
            
            # 验证输入的etcd IP是否在all_ips中
            local found_all=true
            for ip in "${etcd_ips[@]}"; do
                if [[ ! " ${all_ips[@]} " =~ " ${ip} " ]]; then
                    print_error "错误：IP $ip 不在初始节点列表中"
                    found_all=false
                    break
                fi
            done
            
            if [ "$found_all" = true ]; then
                break
            fi
        done
    else
        etcd_ips=("${all_ips[0]}" "${all_ips[1]}" "${all_ips[2]}")
    fi

    print_success "etcd节点配置完成: ${etcd_ips[*]}"
    echo ""

    # 第3步：配置master节点
    echo "=== 第3步：配置master节点 ==="
    default_masters=("${all_ips[0]}" "${all_ips[1]}")
    print_info "高可用集群至少需要2个master节点"
    print_info "默认使用前2个IP作为master节点: ${default_masters[*]}"
    read -p "是否使用默认master节点? (y/n, 默认y): " use_default_master

    if [[ $use_default_master =~ ^[Nn]$ ]]; then
        while true; do
            echo "当前所有可用IP: ${all_ips[*]}"
            read -p "请手动输入master节点IP（用空格分隔，至少2个）: " master_ips_input
            master_ips=($master_ips_input)
            
            if [ ${#master_ips[@]} -lt 2 ]; then
                print_error "错误：master节点至少需要2个"
                continue
            fi
            
            # 验证IP格式
            if ! validate_ip_list "${master_ips[@]}"; then
                continue
            fi
            
            # 验证输入的master IP是否在all_ips中
            local found_all=true
            for ip in "${master_ips[@]}"; do
                if [[ ! " ${all_ips[@]} " =~ " ${ip} " ]]; then
                    print_error "错误：IP $ip 不在初始节点列表中"
                    found_all=false
                    break
                fi
            done
            
            if [ "$found_all" = true ]; then
                break
            fi
        done
    else
        master_ips=("${default_masters[@]}")
    fi

    print_success "master节点配置完成: ${master_ips[*]}"
    echo ""

    # 第4步：配置worker节点
    echo "=== 第4步：配置worker节点 ==="
    # 计算默认的worker节点（所有不在master列表中的节点）
    default_workers=()
    for ip in "${all_ips[@]}"; do
        if [[ ! " ${master_ips[@]} " =~ " ${ip} " ]]; then
            default_workers+=("$ip")
        fi
    done

    if [ ${#default_workers[@]} -eq 0 ]; then
        print_warning "警告：没有可用的worker节点，所有节点都被用作master"
        while true; do
            echo "当前所有可用IP: ${all_ips[*]}"
            read -p "请输入worker节点IP（用空格分隔，至少1个）: " worker_ips_input
            worker_ips=($worker_ips_input)
            
            if [ ${#worker_ips[@]} -lt 1 ]; then
                print_error "错误：worker节点至少需要1个"
                continue
            fi
            
            # 验证IP格式
            if ! validate_ip_list "${worker_ips[@]}"; then
                continue
            fi
            
            # 验证输入的worker IP是否在all_ips中
            local found_all=true
            for ip in "${worker_ips[@]}"; do
                if [[ ! " ${all_ips[@]} " =~ " ${ip} " ]]; then
                    print_error "错误：IP $ip 不在初始节点列表中"
                    found_all=false
                    break
                fi
            done
            
            if [ "$found_all" = true ]; then
                break
            fi
        done
    else
        print_info "默认worker节点（所有非master节点）: ${default_workers[*]}"
        read -p "是否使用默认worker节点? (y/n, 默认y): " use_default_worker

        if [[ $use_default_worker =~ ^[Nn]$ ]]; then
            while true; do
                echo "当前所有可用IP: ${all_ips[*]}"
                read -p "请手动输入worker节点IP（用空格分隔，至少1个）: " worker_ips_input
                worker_ips=($worker_ips_input)
                
                if [ ${#worker_ips[@]} -lt 1 ]; then
                    print_error "错误：worker节点至少需要1个"
                    continue
                fi
                
                # 验证IP格式
                if ! validate_ip_list "${worker_ips[@]}"; then
                    continue
                fi
                
                # 验证输入的worker IP是否在all_ips中
                local found_all=true
                for ip in "${worker_ips[@]}"; do
                    if [[ ! " ${all_ips[@]} " =~ " ${ip} " ]]; then
                        print_error "错误：IP $ip 不在初始节点列表中"
                        found_all=false
                        break
                    fi
                done
                
                if [ "$found_all" = true ]; then
                    break
                fi
            done
        else
            worker_ips=("${default_workers[@]}")
        fi
    fi

    print_success "worker节点配置完成: ${worker_ips[*]}"
    echo ""

    # 第5步：配置域名
    echo "=== 第5步：配置域名 ==="
    # 生成8位随机字符串
    random_str=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    default_domain="qn-${random_str}.hi168.com"

    print_info "默认生成域名: $default_domain"
    read -p "是否使用默认域名? (y/n, 默认y): " use_default_domain

    if [[ $use_default_domain =~ ^[Nn]$ ]]; then
        read -p "请输入自定义域名: " custom_domain
        QN_DOMAIN=$custom_domain
    else
        QN_DOMAIN=$default_domain
    fi

    print_success "域名配置完成: $QN_DOMAIN"
    echo ""

    # 第6步：配置镜像仓库地址
    echo "=== 第6步：配置镜像仓库地址 ==="
    default_registry="harbor.hi168.com/quantanexus"
    print_info "默认镜像仓库地址: $default_registry"
    read -p "是否使用默认镜像仓库地址? (y/n, 默认y): " use_default_registry

    if [[ $use_default_registry =~ ^[Nn]$ ]]; then
        read -p "请输入自定义镜像仓库地址: " custom_registry
        IMAGE_REGISTRY=$custom_registry
    else
        IMAGE_REGISTRY=$default_registry
    fi

    print_success "镜像仓库地址配置完成: $IMAGE_REGISTRY"
    echo ""

    # 生成节点名称映射
    generate_node_names
}

# 收集认证信息

collect_auth_info() {
    echo "=== SSH认证配置 ==="
    print_info "检查SSH公钥认证状态..."
    
    # 检查是否已有SSH密钥对
    if [[ -f "$HOME/.ssh/id_ed25519" && -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        print_success "发现现有的Ed25519密钥对"
    else
        print_warning "未找到现有的Ed25519密钥对"
        read -p "是否生成新的SSH密钥对? (y/n, 默认y): " generate_key
        
        if [[ ! $generate_key =~ ^[Nn]$ ]]; then
            # 生成新的Ed25519密钥对
            print_info "正在生成新的Ed25519 SSH密钥对..."
            ssh-keygen -t ed25519 -b 256 -f "$HOME/.ssh/id_ed25519" -N "" -q
            print_success "SSH密钥对生成完成"
        else
            print_info "跳过SSH密钥对生成"
            return 0
        fi
    fi
    
    # 询问是否使用密码认证
    echo ""
    print_info "您可以选择使用密码认证来配置SSH免密登录"
    read -p "是否使用密码认证配置SSH免密登录? (y/n, 默认y): " use_password
    
    if [[ $use_password =~ ^[Nn]$ ]]; then
        print_info "跳过密码认证配置，请确保已配置SSH免密登录"
        use_password_auth=false
        return 0
    fi
    
    use_password_auth=true
    
    # 收集用户名和密码
    echo ""
    print_info "请输入远程主机的登录信息"
    read -p "用户名 (默认: root): " input_username
    username=${input_username:-root}
    
    echo -n "密码: "
    read -s password
    echo ""
    
    # 确认密码
    echo -n "确认密码: "
    read -s password_confirm
    echo ""
    
    if [[ "$password" != "$password_confirm" ]]; then
        print_error "密码不匹配"
        return 1
    fi
    
    print_success "认证信息收集完成"
    return 0
}

# 显示配置汇总

show_config_summary() {
    echo "=================================================="
    echo "           最终集群配置汇总"
    echo "=================================================="
    print_success "所有节点IP: ${all_ips[*]}"
    print_success "etcd节点: ${etcd_ips[*]}"
    print_success "master节点: ${master_ips[*]}"
    print_success "worker节点: ${worker_ips[*]}"
    print_success "域名: $QN_DOMAIN"
    print_success "镜像仓库: $IMAGE_REGISTRY"
    echo ""
    
    # 显示节点名称映射
    print_success "节点名称映射:"
    for ip in "${!node_names[@]}"; do
        echo "  $ip -> ${node_names[$ip]}"
    done
    echo ""
}
# 生成hosts文件

generate_hosts_file() {
    local output_file="${1:-/dev/stdout}"
    
    echo "=================================================="
    echo "           生成的 hosts 文件内容"
    echo "=================================================="
    echo ""
    
    {
        echo "# 'etcd' cluster should have odd member(s) (1,3,5,...)"
        echo "[etcd]"
        for ip in "${etcd_ips[@]}"; do
            echo "$ip"
        done
        echo ""

        echo "# master node(s), set unique 'k8s_nodename' for each node"
        echo "# CAUTION: 'k8s_nodename' must consist of lower case alphanumeric characters, '-' or '.',"
        echo "# and must start and end with an alphanumeric character"
        echo "[kube_master]"
        for ip in "${master_ips[@]}"; do
            echo "$ip k8s_nodename='${node_names[$ip]}'"
        done
        echo ""

        echo "# work node(s), set unique 'k8s_nodename' for each node"
        echo "# CAUTION: 'k8s_nodename' must consist of lower case alphanumeric characters, '-' or '.',"
        echo "# and must start and end with an alphanumeric character"
        echo "[kube_node]"
        for ip in "${worker_ips[@]}"; do
            echo "$ip k8s_nodename='${node_names[$ip]}'"
        done
        echo ""

        echo "[all:vars]"
        echo "# --------- Main Variables ---------------"
        echo "QN_DOMAIN=\"$QN_DOMAIN\""
        echo "IMAGE_REGISTRY=\"$IMAGE_REGISTRY\""
        echo ""
    } > "$output_file"
    
    if [[ "$output_file" != "/dev/stdout" ]]; then
        print_success "hosts文件已保存到: $output_file"
    else
        print_success "请将上述内容保存到 /etc/kubeasz/clusters/k8s-qn-01/hosts 文件中"
    fi
}


# ==================================================
# 文件: remote_config.sh
# ==================================================

# 远程主机配置模块

# 安装必要工具

install_required_tools() {
    print_info "检查必要工具..."
    
    # 检查ansible
    if ! check_command ansible; then
        print_info "安装ansible..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y ansible sshpass
        elif command -v yum &> /dev/null; then
            yum install -y epel-release
            yum install -y ansible sshpass
        else
            print_error "不支持的包管理器，请手动安装ansible和sshpass"
            return 1
        fi
    fi
    
    # 检查sshpass（用于密码认证）
    if $use_password_auth && ! check_command sshpass; then
        print_info "安装sshpass..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y sshpass
        elif command -v yum &> /dev/null; then
            yum install -y sshpass
        fi
    fi
    
    print_success "必要工具检查完成"
    return 0
}

# 配置SSH免密登录

configure_ssh_access() {
    if ! $use_password_auth; then
        print_info "跳过SSH免密登录配置（使用现有密钥）"
        return 0
    fi
    
    print_info "开始配置SSH免密登录..."
    
    # 读取公钥内容
    if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        ssh_key_content=$(cat "$HOME/.ssh/id_ed25519.pub")
    else
        print_error "未找到SSH公钥文件"
        return 1
    fi
    
    # 为所有节点配置SSH
    for ip in "${all_ips[@]}"; do
        echo ""
        print_info "配置节点 $ip ..."
        
        # 测试连接并配置SSH
        if sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "echo '连接测试成功'"; then
            print_success "成功连接到 $ip"
            echo ""
            
            # 配置SSH免密登录（幂等性操作）
            print_info "配置SSH免密登录..."
            sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                mkdir -p ~/.ssh
                # 检查公钥是否已经存在，避免重复添加
                grep -qFx '$ssh_key_content' ~/.ssh/authorized_keys 2>/dev/null || echo '$ssh_key_content' >> ~/.ssh/authorized_keys
                chmod 700 ~/.ssh
                chmod 600 ~/.ssh/authorized_keys
            "
            echo ""
            
            # 配置root登录（无论当前用户是否为root，都要把公钥加入root账户，保证幂等性）
            print_info "配置root用户SSH访问..."
            sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                echo '$password' | sudo -S mkdir -p /root/.ssh
                # 检查公钥是否已经存在，避免重复添加
                echo '$password' | sudo -S grep -qFx '$ssh_key_content' /root/.ssh/authorized_keys 2>/dev/null || echo '$password' | sudo -S tee -a /root/.ssh/authorized_keys <<< '$ssh_key_content' > /dev/null
                echo '$password' | sudo -S chmod 700 /root/.ssh
                echo '$password' | sudo -S chmod 600 /root/.ssh/authorized_keys
            "
            echo ""
            
            # 修改SSH配置允许root登录
            print_info "修改SSH配置允许root登录..."
            sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                echo '$password' | sudo -S sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
                echo '$password' | sudo -S sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                # 检查sshd服务状态，只有在运行时才重启
                if echo '$password' | sudo -S systemctl is-active ssh >/dev/null 2>&1; then
                    echo '$password' | sudo -S systemctl restart ssh
                elif echo '$password' | sudo -S systemctl is-active sshd >/dev/null 2>&1; then
                    echo '$password' | sudo -S systemctl restart sshd
                fi
            "
            echo ""
            
            print_success "节点 $ip SSH配置完成"
        else
            print_error "无法连接到 $ip，请检查网络和认证信息"
            return 1
        fi
    done
    
    echo ""
    print_success "所有节点SSH免密登录配置完成"
    return 0
}

# 配置主机名

configure_hostnames() {
    print_info "开始配置主机名..."
    
    # 为所有节点配置主机名
    for ip in "${all_ips[@]}"; do
        echo ""
        print_info "配置节点 $ip 的主机名..."
        
        # 获取该IP对应的主机名
        hostname="${node_names[$ip]}"
        if [[ -z "$hostname" ]]; then
            print_warning "未找到IP $ip 的主机名映射，跳过配置"
            continue
        fi
        
        # 构建 hosts 条目（仅包含我们的节点映射）
        {
            echo "# K8s集群节点映射 - 由k8s配置工具自动生成"
            for host_ip in "${!node_names[@]}"; do
                echo "$host_ip ${node_names[$host_ip]}"
            done
        } > /tmp/hosts_nodes_$$_$ip
        
        # 使用SSH密钥认证方式，以root用户连接
        if ssh -o StrictHostKeyChecking=no "root@$ip" "echo '连接测试成功'"; then
            print_success "成功连接到 $ip"
            
            # 设置主机名
            print_info "设置主机名为 $hostname..."
            ssh -o StrictHostKeyChecking=no "root@$ip" "
                hostnamectl set-hostname '$hostname'
            "
            
            # 更新/etc/hosts文件 - 使用追加方式并保持幂等性
            print_info "更新 /etc/hosts 文件（追加模式）..."
            
            # 将节点映射文件传输到远程主机
            scp -o StrictHostKeyChecking=no /tmp/hosts_nodes_$$_$ip "root@$ip":/tmp/hosts_nodes_$$_$ip
            
            # 在远程主机上执行更新操作
            ssh -o StrictHostKeyChecking=no "root@$ip" "
                # 备份原始hosts文件
                cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
                
                # 删除之前由本工具添加的节点映射块（如果存在）
                # 使用特定的开始和结束标记来识别我们添加的内容
                sed -i '/# K8s集群节点映射 - 由k8s配置工具自动生成/,/# K8s集群节点映射 - 结束/d' /etc/hosts
                
                # 追加新的节点映射块到hosts文件末尾
                echo '' >> /etc/hosts
                echo '# K8s集群节点映射 - 由k8s配置工具自动生成' >> /etc/hosts
                cat /tmp/hosts_nodes_$$_$ip | tail -n +2 >> /etc/hosts  # 跳过第一行的注释
                echo '# K8s集群节点映射 - 结束' >> /etc/hosts
                
                # 清理临时文件
                rm -f /tmp/hosts_nodes_$$_$ip
                
                # 验证hosts文件格式
                echo '更新后的hosts文件内容：'
                echo '======================='
                cat /etc/hosts
                echo '======================='
            "
            
            print_success "节点 $ip 主机名配置完成"
        else
            # 清理临时文件
            rm -f /tmp/hosts_nodes_$$_$ip
            print_error "无法连接到 $ip，请检查SSH配置"
            return 1
        fi
        
        # 清理本地临时文件
        rm -f /tmp/hosts_nodes_$$_$ip
    done
    
    echo ""
    print_success "所有节点主机名配置完成"
    return 0
}


# ==================================================
# 文件: install_tools.sh
# ==================================================

# 工具安装模块

# 检查并安装所需的所有工具

install_required_commands() {
    print_info "检查所需命令工具..."
    
    local missing_tools=()
    # 添加 rsync 到必需工具列表
    local required_tools=("ssh" "sshpass" "ansible" "ssh-keygen" "tr" "fold" "head" "cat" "sed" "unzip" "rsync")
    
    # 检查每个必需的工具
    for tool in "${required_tools[@]}"; do
        if ! check_command "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    # 如果没有缺失的工具，则返回
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_success "所有必需的命令工具均已安装"
        return 0
    fi
    
    print_warning "检测到缺失的工具: ${missing_tools[*]}"
    
    # 检查是否有足够权限安装软件包
    if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
        print_error "权限不足且未找到sudo命令，请以root用户运行此脚本或使用sudo"
        return 1
    fi
    
    # 安装缺失的工具
    if command -v apt-get &> /dev/null; then
        print_info "使用 apt-get 安装缺失的工具..."
        if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
            sudo apt-get update
        else
            apt-get update
        fi
        
        local packages_to_install=()
        
        # 根据缺失的工具确定需要安装的包
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "ssh") packages_to_install+=("openssh-client") ;;
                "sshpass") packages_to_install+=("sshpass") ;;
                "ansible") packages_to_install+=("ansible") ;;
                "ssh-keygen") packages_to_install+=("openssh-client") ;;
                "unzip") packages_to_install+=("unzip") ;;
            esac
        done
        
        # 添加通用工具包和 rsync
        packages_to_install+=("coreutils" "sed" "rsync")
        
        # 去重
        local unique_packages=($(echo "${packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#unique_packages[@]} -gt 0 ]; then
            if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                sudo apt-get install -y "${unique_packages[@]}"
            else
                apt-get install -y "${unique_packages[@]}"
            fi
        fi
        
    elif command -v yum &> /dev/null; then
        print_info "使用 yum 安装缺失的工具..."
        local packages_to_install=()
        
        # 根据缺失的工具确定需要安装的包
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "ssh") packages_to_install+=("openssh-clients") ;;
                "sshpass") packages_to_install+=("sshpass") ;;
                "ansible") 
                    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                        sudo yum install -y epel-release
                    else
                        yum install -y epel-release
                    fi
                    packages_to_install+=("ansible")
                    ;;
                "ssh-keygen") packages_to_install+=("openssh") ;;
                "unzip") packages_to_install+=("unzip") ;;
            esac
        done
        
        # 添加通用工具包和 rsync
        packages_to_install+=("coreutils" "sed" "rsync")
        
        # 去重
        local unique_packages=($(echo "${packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#unique_packages[@]} -gt 0 ]; then
            if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                sudo yum install -y "${unique_packages[@]}"
            else
                yum install -y "${unique_packages[@]}"
            fi
        fi
    else
        print_error "不支持的包管理器，请手动安装以下工具: ${missing_tools[*]}"
        return 1
    fi
    
    # 再次验证所有工具是否已安装
    local still_missing=()
    for tool in "${missing_tools[@]}"; do
        if ! check_command "$tool"; then
            still_missing+=("$tool")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        print_error "以下工具安装失败或仍缺失: ${still_missing[*]}"
        return 1
    fi
    
    print_success "所有必需的命令工具安装完成"
    return 0
}


# ==================================================
# 文件: download_source.sh
# ==================================================

# 源码下载模块

# 下载Quantanexus源码

download_source_code() {
    print_info "检查Quantanexus源码..."
    
    # 检查目录是否已存在
    if [[ -d "quantanexus-main" ]]; then
        print_success "Quantanexus源码目录已存在，跳过下载"
        return 0
    fi
    
    print_info "开始下载Quantanexus源码..."
    
    # 尝试通过镜像代理下载
    print_info "尝试通过镜像代理下载..."
    if wget -O main.zip "https://hub.gitmirror.com/https://github.com/hwua-hi168/quantanexus/archive/refs/heads/main.zip"; then
        print_success "通过镜像代理下载成功"
    else
        print_warning "镜像代理下载失败，尝试通过源站下载..."
        # 镜像下载失败，尝试源站下载
        if wget -O main.zip "https://github.com/hwua-hi168/quantanexus/archive/refs/heads/main.zip"; then
            print_success "通过源站下载成功"
        else
            print_error "源码下载失败"
            return 1
        fi
    fi
    
    # 解压文件
    print_info "解压源码文件..."
    if unzip main.zip; then
        print_success "源码解压成功"
        # 清理下载的zip文件
        rm -f main.zip
        return 0
    else
        print_error "源码解压失败"
        return 1
    fi
}


# ==================================================
# 文件: install_kubeasz.sh
# ==================================================

# kubeasz安装模块

# 安装kubeasz

install_kubeasz() {
    print_info "开始安装kubeasz..."
    
    # 检查quantanexus源码是否存在
    if [[ ! -d "quantanexus-main" ]]; then
        print_error "quantanexus源码目录不存在，请先下载源码"
        return 1
    fi
    
    # 进入quantanexus目录中的kubeasz目录
    cd quantanexus-main/install/test/kubeasz || return 1
    
    # 给ezdown脚本添加执行权限
    print_info "设置ezdown执行权限..."
    if ! chmod +x ./ezdown; then
        print_error "无法给ezdown添加执行权限"
        cd ../../..
        return 1
    fi
    
    # 下载kubeasz代码、二进制文件和默认容器镜像
    print_info "下载kubeasz组件（代码、二进制、离线镜像）..."
    if execute_with_privileges ./ezdown -D; then
        print_success "kubeasz组件下载完成，已存放至/etc/kubeasz"
    else
        print_error "kubeasz组件下载失败"
        cd ../../..
        return 1
    fi
    
    # 下载额外容器镜像（cilium）
    print_info "下载cilium容器镜像..."
    if execute_with_privileges ./ezdown -X cilium; then
        print_success "cilium容器镜像下载完成"
    else
        print_error "cilium容器镜像下载失败"
        cd ../../..
        return 1
    fi
    
    # 容器化运行kubeasz
    print_info "容器化运行kubeasz..."
    if execute_with_privileges ./ezdown -S; then
        print_success "kubeasz容器启动成功"
    else
        print_error "kubeasz容器启动失败"
        cd ../../..
        return 1
    fi
    
    cd ../../..
    return 0
}

# 创建集群配置实例

create_cluster_instance() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "创建集群配置实例: $cluster_name"
    
    # 检查kubeasz容器是否运行
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    # 创建新集群
    if execute_with_privileges docker exec -it kubeasz ezctl new "$cluster_name"; then
        print_success "集群 $cluster_name 创建成功"
        print_info "下一步:"
        echo "  1. 配置 '/etc/kubeasz/clusters/$cluster_name/hosts'"
        echo "  2. 配置 '/etc/kubeasz/clusters/$cluster_name/config.yml'"
        return 0
    else
        print_error "集群 $cluster_name 创建失败"
        return 1
    fi
}


# ==================================================
# 文件: configure_kubeasz.sh
# ==================================================

# kubeasz配置模块

# 配置kubeasz

configure_kubeasz() {
    print_info "开始配置kubeasz..."
    
    # 检查quantanexus源码是否存在
    if [[ ! -d "quantanexus-main" ]]; then
        print_error "quantanexus源码目录不存在，请先下载源码"
        return 1
    fi
    
    # 检查kubeasz容器是否运行
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    local cluster_name="k8s-qn-01"
    local kubeasz_cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    local hosts_file="$kubeasz_cluster_dir/hosts"
    
    print_info "配置集群 $cluster_name ..."
    
    # 检查hosts文件是否存在
    if [[ ! -f "$hosts_file" ]]; then
        print_error "hosts文件不存在: $hosts_file"
        return 1
    fi
    
    # 备份原文件
    print_info "备份原hosts文件..."
    execute_with_privileges cp "$hosts_file" "$hosts_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 生成新的配置内容
    local temp_config_file=$(mktemp)
    generate_hosts_file "$temp_config_file"
    
    # 提取各部分的实际内容（去掉空行和注释）
    local etcd_content=$(sed -n '/^\[etcd\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local master_content=$(sed -n '/^\[kube_master\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local worker_content=$(sed -n '/^\[kube_node\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local qn_domain=$(grep "QN_DOMAIN=" "$temp_config_file")
    local image_registry=$(grep "IMAGE_REGISTRY=" "$temp_config_file")  # 新增镜像仓库变量提取
    
    print_info "提取的配置内容:"
    echo "etcd: $etcd_content"
    echo "master: $master_content" 
    echo "worker: $worker_content"
    echo "domain: $qn_domain"
    echo "image_registry: $image_registry"
    
    # 创建临时文件用于存储更新后的内容
    local temp_updated_file=$(mktemp)
    
    # 使用更简单的方法处理文件
    local in_section=""
    local section_updated=false
    
    while IFS= read -r line; do
        # 检测是否进入我们关心的section
        if [[ "$line" =~ ^\[etcd\]$ ]]; then
            in_section="etcd"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[kube_master\]$ ]]; then
            in_section="master"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[kube_node\]$ ]]; then
            in_section="worker"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[all:vars\]$ ]]; then
            in_section="vars"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        fi
        
        # 如果遇到下一个section，重置状态
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ -n "$in_section" ]]; then
            in_section=""
        fi
        
        # 处理各个section的内容
        case "$in_section" in
            "etcd")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的etcd内容
                    echo "$etcd_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的etcd内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "master")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的master内容
                    echo "$master_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的master内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "worker")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的worker内容
                    echo "$worker_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的worker内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "vars")
                # 处理QN_DOMAIN变量
                if [[ "$line" =~ ^QN_DOMAIN= ]]; then
                    # 替换现有的QN_DOMAIN
                    echo "$qn_domain" >> "$temp_updated_file"
                    section_updated=true
                # 处理IMAGE_REGISTRY变量
                elif [[ "$line" =~ ^IMAGE_REGISTRY= ]]; then
                    # 替换现有的IMAGE_REGISTRY
                    echo "$image_registry" >> "$temp_updated_file"
                    section_updated=true
                else
                    echo "$line" >> "$temp_updated_file"
                    # 如果没有找到QN_DOMAIN，在适当位置添加
                    if [[ "$section_updated" == false ]] && [[ "$line" =~ ^#.*Main.Variables ]]; then
                        echo "$qn_domain" >> "$temp_updated_file"
                        echo "$image_registry" >> "$temp_updated_file"
                        section_updated=true
                    fi
                fi
                ;;
            *)
                # 不在我们关心的section中，直接输出
                echo "$line" >> "$temp_updated_file"
                ;;
        esac
    done < "$hosts_file"
    
    # 如果QN_DOMAIN在vars section中还没有被处理，添加到vars section末尾
    if grep -q "\[all:vars\]" "$temp_updated_file" && ! grep -q "QN_DOMAIN=" "$temp_updated_file"; then
        sed -i '/\[all:vars\]/a\'"$qn_domain" "$temp_updated_file"
    fi
    
    # 如果IMAGE_REGISTRY在vars section中还没有被处理，添加到vars section末尾
    if grep -q "\[all:vars\]" "$temp_updated_file" && ! grep -q "IMAGE_REGISTRY=" "$temp_updated_file"; then
        sed -i '/\[all:vars\]/a\'"$image_registry" "$temp_updated_file"
    fi
    
    # 替换原文件
    if execute_with_privileges cp "$temp_updated_file" "$hosts_file"; then
        print_success "hosts文件更新完成"
    else
        print_error "hosts文件更新失败"
        rm -f "$temp_config_file" "$temp_updated_file"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$temp_config_file" "$temp_updated_file"
    
    # 显示更新后的文件内容
    print_info "更新后的hosts文件内容:"
    execute_with_privileges cat "$hosts_file"
    
    # 同步自定义的代码到kubeasz中
    print_info "同步自定义代码到kubeasz..."
    
    if execute_with_privileges rsync -a quantanexus-main/install/test/kubeasz/playbooks/ /etc/kubeasz/playbooks/ && \
       execute_with_privileges rsync -a quantanexus-main/install/test/kubeasz/roles/ /etc/kubeasz/roles/; then
        print_success "自定义代码已同步到kubeasz"
    else
        print_error "同步自定义代码失败"
        return 1
    fi
    
    print_success "kubeasz配置完成"
    return 0
}


# ==================================================
# 文件: run_kubeasz_setup.sh
# ==================================================

# kubeasz执行模块

# kubeasz步骤描述
declare -A kubeasz_steps=(
    ["01"]="准备节点环境"
    ["02"]="安装etcd集群"
    ["03"]="安装docker"
    ["04"]="安装k8s基础组件"
    ["05"]="安装master节点"
    ["06"]="安装网络插件"
    ["07"]="安装localDNS"
)

# 显示kubeasz步骤信息

show_kubeasz_steps() {
    echo "=================================================="
    echo "           kubeasz 安装步骤说明"
    echo "=================================================="
    echo ""
    for step in "${!kubeasz_steps[@]}"; do
        echo "步骤 $step: ${kubeasz_steps[$step]}"
    done
    echo ""
}

# 检查kubeasz容器状态

check_kubeasz_container() {
    print_info "检查kubeasz容器状态..."
    
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    print_success "kubeasz容器运行正常"
    return 0
}

# 执行kubeasz单步安装

run_kubeasz_single_step() {
    local cluster_name="$1"
    local step="$2"
    
    if [[ -z "$cluster_name" || -z "$step" ]]; then
        print_error "缺少参数: 集群名称和步骤编号"
        return 1
    fi
    
    # 验证步骤编号
    if [[ ! "${!kubeasz_steps[@]}" =~ "$step" ]]; then
        print_warning "步骤 $step 不在预定义步骤列表中，但将继续执行"
    fi
    
    print_info "执行kubeasz步骤 $step: ${kubeasz_steps[$step]:-未知步骤}"
    
    # 执行安装步骤
    if execute_with_privileges docker exec -it kubeasz ezctl setup "$cluster_name" "$step"; then
        print_success "kubeasz步骤 $step 执行完成"
        return 0
    else
        print_error "kubeasz步骤 $step 执行失败"
        return 1
    fi
}

# 执行kubeasz分步安装

run_kubeasz_setup() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始执行kubeasz分步安装..."
    
    # 检查kubeasz容器
    if ! check_kubeasz_container; then
        return 1
    fi
    
    # 显示步骤信息
    show_kubeasz_steps
    
    # 确认是否继续
    read -p "是否开始执行kubeasz安装? (y/n, 默认y): " confirm_start
    if [[ $confirm_start =~ ^[Nn]$ ]]; then
        print_info "用户取消安装"
        return 0
    fi
    
    # 定义安装步骤顺序
    local steps=("01" "02" "03" "04" "05" "06" "07")
    
    # 执行每个步骤
    for step in "${steps[@]}"; do
        echo ""
        print_info "=== 开始执行步骤 $step: ${kubeasz_steps[$step]} ==="
        
        # 执行当前步骤
        if ! run_kubeasz_single_step "$cluster_name" "$step"; then
            print_error "步骤 $step 执行失败，安装中止"
            
            # 询问是否继续执行后续步骤
            read -p "是否跳过此步骤继续执行后续步骤? (y/n, 默认n): " skip_step
            if [[ ! $skip_step =~ ^[Yy]$ ]]; then
                return 1
            else
                print_warning "跳过步骤 $step，继续执行后续步骤"
                continue
            fi
        fi
        
        # 步骤间暂停（可选）
        if [[ "$step" != "07" ]]; then
            echo ""
            read -p "步骤 $step 完成，按回车继续下一步骤..." dummy
        fi
    done
    
    echo ""
    print_success "所有kubeasz安装步骤执行完成！"
    
    # 显示完成信息
    echo ""
    echo "=================================================="
    echo "          K8s集群安装完成"
    echo "=================================================="
    echo ""
    echo "集群信息:"
    echo "  - 集群名称: $cluster_name"
    echo "  - 域名: $QN_DOMAIN"
    echo "  - Master节点: ${#master_ips[@]} 个"
    echo "  - Worker节点: ${#worker_ips[@]} 个"
    echo ""
    echo "下一步操作:"
    echo "  1. 检查集群状态: docker exec -it kubeasz ezctl status $cluster_name"
    echo "  2. 查看集群节点: docker exec -it kubeasz kubectl get nodes"
    echo "  3. 查看所有Pod: docker exec -it kubeasz kubectl get pods -A"
    echo ""
    
    return 0
}

# 检查集群状态

check_cluster_status() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "检查集群 $cluster_name 状态..."
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    if execute_with_privileges docker exec -it kubeasz ezctl status "$cluster_name"; then
        print_success "集群状态检查完成"
        return 0
    else
        print_error "集群状态检查失败"
        return 1
    fi
}

# 显示集群信息

show_cluster_info() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "显示集群 $cluster_name 信息..."
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群节点信息"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get nodes -o wide; then
        print_error "获取节点信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群Pod状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get pods -A; then
        print_error "获取Pod信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群服务状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get svc -A; then
        print_error "获取服务信息失败"
        return 1
    fi
    
    return 0
}


# ==================================================
# 文件: install_helm.sh
# ==================================================

# Helm安装模块

# 执行Helm安装

install_helm() {
    print_info "开始安装Helm..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_name="${1:-k8s-qn-01}"
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Helm安装的ansible-playbook
    print_info "执行Helm安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/41.helm.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/41.helm.yml; then
        print_success "Helm安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Helm安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_longhorn.sh
# ==================================================

# Longhorn安装模块

run_longhorn_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Longhorn存储..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Longhorn安装的ansible-playbook
    print_info "执行Longhorn安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/longhorn.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/longhorn.yml; then
        print_success "Longhorn存储安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Longhorn存储安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_cert_manager.sh
# ==================================================

# Cert-Manager安装模块

run_cert_manager_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Cert-Manager..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Cert-Manager安装的ansible-playbook
    print_info "执行Cert-Manager安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/cert-manager.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/cert-manager.yml; then
        print_success "Cert-Manager安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Cert-Manager安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_prometheus.sh
# ==================================================

# Prometheus安装模块

run_prometheus_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Prometheus监控..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Prometheus安装的ansible-playbook
    print_info "执行Prometheus安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/prometheus.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/prometheus.yml; then
        print_success "Prometheus监控安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Prometheus监控安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_ingress_nginx.sh
# ==================================================

# Ingress-Nginx安装模块

run_ingress_nginx_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Ingress-Nginx..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Ingress-Nginx安装的ansible-playbook
    print_info "执行Ingress-Nginx安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/ingress-nginx.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/ingress-nginx.yml; then
        print_success "Ingress-Nginx安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Ingress-Nginx安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_harbor.sh
# ==================================================

# Harbor安装模块

run_harbor_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Harbor镜像仓库..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Harbor安装的ansible-playbook
    print_info "执行Harbor安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/harbor.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/harbor.yml; then
        print_success "Harbor镜像仓库安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Harbor镜像仓库安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_gpu_operator.sh
# ==================================================

# GPU Operator安装模块

run_gpu_operator_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装GPU Operator..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行GPU Operator安装的ansible-playbook
    print_info "执行GPU Operator安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/gpu-operator.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/gpu-operator.yml; then
        print_success "GPU Operator安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "GPU Operator安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_volcano.sh
# ==================================================

# Volcano安装模块

run_volcano_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Volcano批处理系统..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Volcano安装的ansible-playbook
    print_info "执行Volcano安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/volcano.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/volcano.yml; then
        print_success "Volcano批处理系统安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Volcano批处理系统安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_quantanexus_mgr.sh
# ==================================================

# Quantanexus管理组件安装模块

run_quantanexus_mgr_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Quantanexus管理组件..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Quantanexus管理组件安装的ansible-playbook
    print_info "执行Quantanexus管理组件安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/quantanexus-mgr.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/quantanexus-mgr.yml; then
        print_success "Quantanexus管理组件安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Quantanexus管理组件安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: run_quantanexus_cs.sh
# ==================================================

# Quantanexus计算服务安装模块

run_quantanexus_cs_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Quantanexus计算服务..."
    
    # 检查kubeasz是否已安装
    if [[ ! -d "/etc/kubeasz" ]]; then
        print_error "kubeasz未安装，请先安装kubeasz"
        return 1
    fi
    
    # 检查集群配置是否存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ ! -d "$cluster_dir" ]]; then
        print_error "集群配置目录不存在: $cluster_dir"
        return 1
    fi
    
    # 检查必要的配置文件
    if [[ ! -f "$cluster_dir/hosts" ]]; then
        print_error "集群hosts文件不存在: $cluster_dir/hosts"
        return 1
    fi
    
    if [[ ! -f "$cluster_dir/config.yml" ]]; then
        print_error "集群配置文件不存在: $cluster_dir/config.yml"
        return 1
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Quantanexus计算服务安装的ansible-playbook
    print_info "执行Quantanexus计算服务安装: ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/quantanexus-cs.yml"
    
    if execute_with_privileges ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/quantanexus-cs.yml; then
        print_success "Quantanexus计算服务安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Quantanexus计算服务安装失败"
        cd "$original_dir"
        return 1
    fi
}


# ==================================================
# 文件: main.sh
# ==================================================

# 主控程序 - K8s集群配置工具

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入公共函数和变量

# 导入其他模块

# 新增组件安装模块

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
    echo "  longhorn     安装Longhorn存储"
    echo "  cert-manager 安装Cert-Manager"
    echo "  prometheus   安装Prometheus监控"
    echo "  ingress-nginx 安装Ingress-Nginx"
    echo "  harbor       安装Harbor镜像仓库"
    echo "  gpu-operator 安装GPU Operator"
    echo "  volcano      安装Volcano批处理系统"
    echo "  quantanexus-mgr 安装Quantanexus管理组件"
    echo "  quantanexus-cs 安装Quantanexus计算服务"
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
IMAGE_REGISTRY="$IMAGE_REGISTRY"
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
            if ! run_longhorn_playbook; then
                print_error "Longhorn安装失败"
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

