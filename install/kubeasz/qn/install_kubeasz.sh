#!/bin/bash

# kubeasz安装模块

# 安装kubeasz
install_kubeasz() {
    print_info "开始安装kubeasz..."
    cd $SCRIPT_DIR
    # 检查quantanexus源码是否存在
    if [[ ! -d "quantanexus-main" ]]; then
        print_error "quantanexus源码目录不存在，请先下载源码"
        return 1
    fi
    
    # 进入quantanexus目录中的kubeasz目录
    cd quantanexus-main/install/kubeasz || return 1
    
    # 获取最新的标签
    print_info "获取Quantanexus最新标签..."
    QNI_VER=$(curl -s "https://api.github.com/repos/hwua-hi168/quantanexus/tags" | grep -o '"name": "[^"]*' | head -1 | cut -d'"' -f4)

    sed "s/{{ QNI_VER }}/$QNI_VER/" ezdown.in > ezdown
    
    # 给ezdown脚本添加执行权限
    print_info "设置ezdown执行权限..."
    if ! chmod +x ./ezdown; then
        print_error "无法给ezdown添加执行权限"
        cd ../../..
        return 1
    fi
    
    # 下载kubeasz代码、二进制文件和默认容器镜像
    print_info "下载kubeasz组件（代码、二进制、离线镜像）..."
    if execute_with_privileges ./ezdown -D; then
        print_success "kubeasz组件下载完成，已存放至/etc/kubeasz"
    else
        print_error "kubeasz组件下载失败"
        cd ../../..
        return 1
    fi
    
    # 下载额外容器镜像（cilium）
    print_info "下载cilium容器镜像..."
    if execute_with_privileges ./ezdown -X cilium; then
        print_success "cilium容器镜像下载完成"
    else
        print_error "cilium容器镜像下载失败"
        cd ../../..
        return 1
    fi
    
    # 容器化运行kubeasz
    print_info "容器化运行kubeasz..."
    if execute_with_privileges ./ezdown -S; then
        print_success "kubeasz容器启动成功"
    else
        print_error "kubeasz容器启动失败"
        cd ../../..
        return 1
    fi
    
    cd ../../..
    return 0
}

# 创建集群配置实例
create_cluster_instance() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "创建集群配置实例: $cluster_name"
    
    # 检查集群实例目录是否已存在
    local cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    if [[ -d "$cluster_dir" ]]; then
        print_info "集群实例 $cluster_name 已存在，跳过创建"
        return 0
    fi
    
    # 检查kubeasz容器是否运行
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    # 创建新集群
    if execute_with_privileges docker exec -it kubeasz ezctl new "$cluster_name"; then
        print_success "集群 $cluster_name 创建成功"
        print_info "下一步:"
        echo "  1. 配置 '/etc/kubeasz/clusters/$cluster_name/hosts'"
        echo "  2. 配置 '/etc/kubeasz/clusters/$cluster_name/config.yml'"
        return 0
    else
        print_error "集群 $cluster_name 创建失败"
        return 1
    fi
}
