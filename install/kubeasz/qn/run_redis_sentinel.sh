#!/bin/bash

# Redis Sentinel安装模块

run_redis_sentinel_playbook() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始安装Redis Sentinel..."
    
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
    
    # 检查Redis Sentinel是否已经安装
    print_info "检查Redis Sentinel是否已经安装..."
    if execute_with_privileges helm status redis-sentinel -n redis-system >/dev/null 2>&1; then
        print_warning "Redis Sentinel已经安装，跳过安装步骤"
        cd "$original_dir"
        return 0
    else
        print_info "Redis Sentinel未安装，继续执行安装"
    fi
    
    # 进入kubeasz目录执行安装
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行Redis Sentinel安装的ansible-playbook
    print_info "执行Redis Sentinel安装: docker exec -it -w /etc/kubeasz kubeasz ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/redis-sentinel.yml"
    
    if execute_with_privileges docker exec -it -w /etc/kubeasz kubeasz ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/redis-sentinel.yml; then
        print_success "Redis Sentinel安装完成"
        cd "$original_dir"
        return 0
    else
        print_error "Redis Sentinel安装失败"
        cd "$original_dir"
        return 1
    fi
}