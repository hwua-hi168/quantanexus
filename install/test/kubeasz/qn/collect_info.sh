#!/bin/bash

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
        echo ""
    } > "$output_file"
    
    if [[ "$output_file" != "/dev/stdout" ]]; then
        print_success "hosts文件已保存到: $output_file"
    else
        print_success "请将上述内容保存到 /etc/kubeasz/clusters/your-cluster-name/hosts 文件中"
    fi
}