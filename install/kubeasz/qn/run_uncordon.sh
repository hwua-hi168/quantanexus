#!/bin/bash

# Uncordon节点模块

run_uncordon_masters() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "执行节点 uncordon 操作..."
    
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
    
    # 进入kubeasz目录执行操作
    local original_dir=$(pwd)
    cd /etc/kubeasz || return 1
    
    # 执行ansible playbook进行uncordon操作
    print_info "执行uncordon: docker exec -it -w /etc/kubeasz kubeasz ansible-playbook -i clusters/$cluster_name/hosts -e @clusters/$cluster_name/config.yml playbooks/uncordon.yml"
    
    if execute_with_privileges docker exec -it -w /etc/kubeasz kubeasz ansible-playbook -i "clusters/$cluster_name/hosts" -e "@clusters/$cluster_name/config.yml" playbooks/uncordon.yml; then
        print_success "节点 uncordon 操作完成"
        cd "$original_dir"
        return 0
    else
        print_error "节点 uncordon 操作失败"
        cd "$original_dir"
        return 1
    fi
}