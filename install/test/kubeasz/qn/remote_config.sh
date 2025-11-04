#!/bin/bash

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
