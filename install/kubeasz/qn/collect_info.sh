#!/bin/bash

# 收集用户信息模块

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
QN_CS_DOMAIN="$QN_CS_DOMAIN"
IMAGE_REGISTRY="$IMAGE_REGISTRY"
username="$username"
password="$password"
use_password_auth="$use_password_auth"
node_names_mappings="$node_names_mappings"
USE_HTTP_IP="$USE_HTTP_IP"
MGR_DOMAIN_IP="$MGR_DOMAIN_IP"
EOF
    
    print_success "配置已保存到 $SCRIPT_DIR/.k8s_cluster_config"
}

# 检查是否已有配置
check_existing_config() {
    echo "all_ips $all_ips"
    echo "etcd_ips $etcd_ips"
    echo "master_ips $master_ips"
    echo "worker_ips $worker_ips"
    echo "QN_DOMAIN $QN_DOMAIN"
    echo "IMAGE_REGISTRY $IMAGE_REGISTRY"
    if [[ -n "$all_ips" && -n "$etcd_ips" && -n "$master_ips" && -n "$worker_ips" && -n "$QN_DOMAIN" && -n "$IMAGE_REGISTRY" ]]; then
        echo "=== 检测到已有配置信息 ==="
        show_config_summary
        
        read -p "是否使用以上配置? (y/n, 默认y): " use_existing_config
        if [[ ! $use_existing_config =~ ^[Nn]$ ]]; then
            print_success "使用现有配置"
            return 0
        else
            print_info "重新配置节点信息..."
            # 清空现有配置
            unset all_ips etcd_ips master_ips worker_ips QN_DOMAIN IMAGE_REGISTRY node_names USE_HTTP_IP MGR_DOMAIN_IP
        fi
    fi
    return 1
}

# 配置节点信息
configure_nodes() {
    # 首先检查是否已有配置
    if check_existing_config; then
        return 0
    fi
    
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
    
    # 新增：判断是否使用IP直接访问
    echo "=== 第5步：配置访问方式 ==="
    print_info "是否使用IP直接访问（不使用域名）Quantanexus管理组件和计算服务?"
    # 🌟 修改点：将默认提示改为 (y/n, 默认y)
    read -p "使用IP直接访问? (y/n, 默认y): " use_http_ip_input
    
    # 🌟 修改点：判断逻辑调整，如果输入是'N'或'n'，则走域名流程；否则（包括空和'y'）走IP流程。
    if [[ $use_http_ip_input =~ ^[Nn]$ ]]; then
        USE_HTTP_IP="false"
        MGR_DOMAIN_IP=""
        
        # 第5.1步：配置域名
        echo "=== 第5.1步：配置域名 ==="
        # 生成8位随机字符串
        random_str=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 | tr 'A-Z' 'a-z')
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
    
        # 第5.2步：配置Quantanexus Service域名
        echo "=== 第5.2步：配置Quantanexus Service域名 ==="
        print_info "Quantanexus Service是否使用与主域名相同的域名?"
        print_info "默认使用相同域名: $QN_DOMAIN"
        read -p "是否使用相同域名? (y/n, 默认y): " use_same_cs_domain
    
        if [[ $use_same_cs_domain =~ ^[Nn]$ ]]; then
            read -p "请输入Quantanexus Service域名: " custom_cs_domain
            QN_CS_DOMAIN=$custom_cs_domain
        else
            QN_CS_DOMAIN=$QN_DOMAIN
        fi
    
        print_success "Quantanexus Service域名配置完成: $QN_CS_DOMAIN"
        echo ""
    else
        # 默认或明确输入 'y'
        USE_HTTP_IP="true"
        QN_DOMAIN=""
        QN_CS_DOMAIN=""
        print_success "配置为使用IP直接访问"
        
        # 收集 MGR_DOMAIN_IP
        default_mgr_ip="${all_ips[0]}" # 默认使用第一个 IP
        print_info "请输入用于访问Quantanexus管理组件的IP地址 (MGR_DOMAIN_IP)"
        print_info "默认IP为第一个节点IP: $default_mgr_ip"
        read -p "请输入MGR_DOMAIN_IP (默认: $default_mgr_ip): " mgr_domain_ip_input
        
        MGR_DOMAIN_IP=${mgr_domain_ip_input:-$default_mgr_ip}
        
        # 验证 MGR_DOMAIN_IP 是否在所有 IP 列表中
        local found_mgr_ip=false
        for ip in "${all_ips[@]}"; do
            if [[ "$ip" == "$MGR_DOMAIN_IP" ]]; then
                found_mgr_ip=true
                break
            fi
        done
        
        if [ "$found_mgr_ip" == "false" ]; then
            print_warning "警告: MGR_DOMAIN_IP ($MGR_DOMAIN_IP) 不在您提供的集群节点列表中"
        fi
        
        # 假设 validate_ip 已经存在于 common.sh 中
        if ! validate_ip "$MGR_DOMAIN_IP"; then
            print_error "错误: MGR_DOMAIN_IP ($MGR_DOMAIN_IP) 格式无效"
            # 这里可以考虑退出或强制用户重新输入，为简化处理，暂时仅报错
        fi
        
        print_success "MGR_DOMAIN_IP 配置完成: $MGR_DOMAIN_IP"
        echo ""
    fi
    

    # 第6步：配置镜像仓库地址
    echo "=== 第6步：配置镜像仓库地址 ==="
    default_registry="registry.cn-hangzhou.aliyuncs.com/quantanexus"
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
    
    # 保存配置到文件
    save_config
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
            # 即使跳过，我们也需要调用 save_config 来确保 use_password_auth 等其他变量被保存
            save_config 
            return 0
        fi
    fi
    
    # 询问是否使用密码认证
    if [[ -z $use_password_auth ]]; then
      echo ""
      print_info "您可以选择使用密码认证来配置SSH免密登录"
      read -p "是否使用密码认证配置SSH免密登录? (y/n, 默认y): " use_password
      
      if [[ $use_password =~ ^[Nn]$ ]]; then
          print_info "跳过密码认证配置，请确保已配置SSH免密登录"
          use_password_auth=false
          save_config # 即使跳过，也要保存 use_password_auth=false
          return 0
      fi
    fi
    
    use_password_auth=true
    
    # 收集用户名和密码
    if [[ -z $username ]]; then
      echo ""
      print_info "请输入远程主机的登录信息"
      read -p "用户名 (默认: root): " input_username
      username=${input_username:-root}
    fi
    if [[ -z $password ]]; then
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
    fi    
    
    print_success "认证信息收集完成"
    # 添加 save_config，确保用户名和密码被保存到配置文件
    save_config
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
    
    if [[ "$USE_HTTP_IP" == "true" ]]; then
        print_success "访问方式: IP直接访问 (USE_HTTP_IP=true)"
        print_success "管理组件IP (MGR_DOMAIN_IP): $MGR_DOMAIN_IP"
        print_warning "域名 (QN_DOMAIN/QN_CS_DOMAIN): (未配置)"
    else
        print_success "访问方式: 域名访问 (USE_HTTP_IP=false)"
        print_success "域名 (QN_DOMAIN): $QN_DOMAIN"
        print_success "Quantanexus Service域名 (QN_CS_DOMAIN): $QN_CS_DOMAIN"
        print_warning "管理组件IP (MGR_DOMAIN_IP): (未配置)"
    fi
    
    print_success "镜像仓库: $IMAGE_REGISTRY"
    echo ""
    
    # 显示节点名称映射
    print_success "节点名称映射:"
    for ip in "${!node_names[@]}"; do
        echo "  $ip -> ${node_names[$ip]}"
    done
    
    # 显示认证信息 (避免显示明文密码)
    print_success "SSH用户名: $username"
    if [[ "$use_password_auth" == "true" ]]; then
        print_success "认证方式: 密码认证 (密码已保存)"
    else
        print_success "认证方式: SSH密钥认证"
    fi
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
        echo "QN_CS_DOMAIN=\"$QN_CS_DOMAIN\""
        echo "IMAGE_REGISTRY=\"$IMAGE_REGISTRY\""
        echo "USE_HTTP_IP=\"$USE_HTTP_IP\""
        echo "MGR_DOMAIN_IP=\"$MGR_DOMAIN_IP\""
        echo ""
    } > "$output_file"
    
    if [[ "$output_file" != "/dev/stdout" ]]; then
        print_success "hosts文件已保存到: $output_file"
    else
        print_success "请将上述内容保存到 /etc/kubeasz/clusters/k8s-qn-01/hosts 文件中"
    fi
}