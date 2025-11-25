#!/bin/bash

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
        print_warning "命令 $1 未找到，请先安装"
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
