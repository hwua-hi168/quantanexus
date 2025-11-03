#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示欢迎信息
echo "=================================================="
echo "    K8s 高可用集群规划配置工具"
echo "=================================================="
echo ""
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

# 生成节点名称（按照新的命名规则）
generate_master_node_name() {
    local index=$1
    echo "k8s-master-${index}"
}

generate_worker_node_name() {
    local index=$1
    echo "k8s-worker-${index}"
}

# 显示最终配置
echo "=================================================="
echo "           最终集群配置汇总"
echo "=================================================="
print_success "所有节点IP: ${all_ips[*]}"
print_success "etcd节点: ${etcd_ips[*]}"
print_success "master节点: ${master_ips[*]}"
print_success "worker节点: ${worker_ips[*]}"
print_success "域名: $QN_DOMAIN"
echo ""

# 生成hosts文件内容
echo "=================================================="
echo "           生成的 hosts 文件内容"
echo "=================================================="
echo ""
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
for i in "${!master_ips[@]}"; do
    node_name=$(generate_master_node_name "$((i+1))")
    echo "${master_ips[i]} k8s_nodename='$node_name'"
done
echo ""

echo "# work node(s), set unique 'k8s_nodename' for each node"
echo "# CAUTION: 'k8s_nodename' must consist of lower case alphanumeric characters, '-' or '.',"
echo "# and must start and end with an alphanumeric character"
echo "[kube_node]"
for i in "${!worker_ips[@]}"; do
    node_name=$(generate_worker_node_name "$((i+1))")
    echo "${worker_ips[i]} k8s_nodename='$node_name'"
done
echo ""

echo "[all:vars]"
echo "# --------- Main Variables ---------------"
echo "QN_DOMAIN=\"$QN_DOMAIN\""
echo ""

print_success "配置完成！请将上述内容保存到 /etc/kubeasz/clusters/your-cluster-name/hosts 文件中"