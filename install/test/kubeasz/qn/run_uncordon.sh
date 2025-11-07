#!/bin/bash

# Uncordon节点模块

run_uncordon_masters() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始执行节点 uncordon 操作..."
    
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
    
    # 从load_config函数获取master节点名称
    local master_nodes=()
    
    # 使用load_config函数加载的master_ips和node_names变量
    for ip in "${master_ips[@]}"; do
        if [[ -n "${node_names[$ip]}" ]]; then
            master_nodes+=("${node_names[$ip]}")
        fi
    done
    
    if [[ ${#master_nodes[@]} -eq 0 ]]; then
        print_warning "未找到master节点信息"
        cd "$original_dir"
        return 0
    fi
    
    # 对每个master节点执行uncordon操作
    for node in "${master_nodes[@]}"; do
        print_info "执行节点 uncordon: $node"
        if execute_with_privileges /opt/kube/bin/kubectl uncordon "$node"; then
            print_success "节点 $node uncordon 成功"
        else
            print_error "节点 $node uncordon 失败"
            cd "$original_dir"
            return 1
        fi
    done
    
    print_success "所有master节点 uncordon 操作完成"
    cd "$original_dir"
    return 0
}