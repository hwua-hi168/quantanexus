#!/bin/bash

# containerd配置模块

# 配置containerd镜像仓库
configure_containerd_registry() {
    print_info "开始配置containerd镜像仓库..."
    
    # 检查是否在kubeasz环境中运行
    if ! check_environment; then
        print_error "未检测到kubeasz环境，请确保在kubeasz容器中运行"
        return 1
    fi
    
    local cluster_name="${1:-k8s-qn-01}"
    local playbook_name="containerd-registry-config"
    
    print_info "执行playbook: $playbook_name"
    
    # 在kubeasz容器中执行playbook
    if execute_with_privileges docker exec -it -w /etc/kubeasz kubeasz ansible-playbook \
        -i "clusters/$cluster_name/hosts" \
        "playbooks/$playbook_name.yml"; then
        print_success "containerd镜像仓库配置完成"
        return 0
    else
        print_error "containerd镜像仓库配置失败"
        return 1
    fi
}