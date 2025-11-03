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
        print_info "配置节点 $ip ..."
        
        # 测试连接并配置SSH
        if sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "echo '连接测试成功'"; then
            print_success "成功连接到 $ip"
            
            # 配置SSH免密登录
            print_info "配置SSH免密登录..."
            sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                mkdir -p ~/.ssh
                echo '$ssh_key_content' >> ~/.ssh/authorized_keys
                chmod 700 ~/.ssh
                chmod 600 ~/.ssh/authorized_keys
            "
            
            # 配置root登录（如果当前用户不是root）
            if [[ "$username" != "root" ]]; then
                print_info "配置root用户SSH访问..."
                sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                    sudo mkdir -p /root/.ssh
                    sudo bash -c \"echo '$ssh_key_content' >> /root/.ssh/authorized_keys\"
                    sudo chmod 700 /root/.ssh
                    sudo chmod 600 /root/.ssh/authorized_keys
                "
            fi
            
            # 修改SSH配置允许root登录
            print_info "修改SSH配置允许root登录..."
            sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" "
                sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo systemctl restart sshd
            "
            
            print_success "节点 $ip SSH配置完成"
        else
            print_error "无法连接到 $ip，请检查网络和认证信息"
            return 1
        fi
    done
    
    print_success "所有节点SSH免密登录配置完成"
    return 0
}

# 配置主机名
configure_hostnames() {
    print_info "开始配置主机名..."
    
    # 创建Ansible inventory文件
    local inventory_file="/tmp/k8s_hosts_$$"
    cat > "$inventory_file" << EOF
[all]
$(for ip in "${all_ips[@]}"; do echo "$ip"; done)

[all:vars]
ansible_ssh_private_key_file=$HOME/.ssh/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
    
    # 创建Ansible playbook配置主机名
    local playbook_file="/tmp/k8s_hostname_$$.yml"
    cat > "$playbook_file" << EOF
---
- name: Configure K8s node hostnames
  hosts: all
  become: yes
  tasks:
    - name: Set hostname according to mapping
      hostname:
        name: "{{ hostname_map[inventory_hostname] }}"
      when: hostname_map[inventory_hostname] is defined
      
    - name: Update /etc/hosts with all nodes
      lineinfile:
        path: /etc/hosts
        line: "{{ item.value }} {{ item.key }}"
        state: present
      loop: "{{ hostname_map | dict2items }}"
      when: hostname_map[inventory_hostname] is defined
EOF
    
    # 准备主机名映射变量
    local hostname_vars=""
    for ip in "${!node_names[@]}"; do
        hostname_vars+="\"$ip\": \"${node_names[$ip]}\","
    done
    hostname_vars="{${hostname_vars%,}}"
    
    # 执行Ansible配置主机名
    if ansible all -i "$inventory_file" -m ping > /dev/null 2>&1; then
        print_info "通过Ansible配置主机名..."
        ansible-playbook -i "$inventory_file" "$playbook_file" \
            --extra-vars "hostname_map=$hostname_vars"
        
        if [ $? -eq 0 ]; then
            print_success "主机名配置完成"
        else
            print_error "主机名配置失败"
            return 1
        fi
    else
        print_error "Ansible连接测试失败，无法配置主机名"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$inventory_file" "$playbook_file"
    
    return 0
}