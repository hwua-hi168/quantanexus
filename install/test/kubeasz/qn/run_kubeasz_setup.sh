#!/bin/bash

# kubeasz执行模块

# kubeasz步骤描述 - 按正确的执行顺序排列
declare -A kubeasz_steps=(
    ["01"]="准备节点环境"
    ["02"]="安装etcd集群"
    ["03"]="安装docker"
    ["04"]="安装k8s基础组件"
    ["05"]="安装master节点"
    ["06"]="安装网络插件"
    ["07"]="安装localDNS"
)

# 显示kubeasz步骤信息
show_kubeasz_steps() {
    echo "=================================================="
    echo "           kubeasz 安装步骤说明"
    echo "=================================================="
    echo ""
    # 按顺序显示步骤
    for step in "01" "02" "03" "04" "05" "06" "07"; do
        echo "步骤 $step: ${kubeasz_steps[$step]}"
    done
    echo ""
}

# 检查kubeasz容器状态
check_kubeasz_container() {
    print_info "检查kubeasz容器状态..."
    
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    print_success "kubeasz容器运行正常"
    return 0
}

# 执行kubeasz单步安装
run_kubeasz_single_step() {
    local cluster_name="$1"
    local step="$2"
    
    if [[ -z "$cluster_name" || -z "$step" ]]; then
        print_error "缺少参数: 集群名称和步骤编号"
        return 1
    fi
    
    # 验证步骤编号
    if [[ ! "${!kubeasz_steps[@]}" =~ "$step" ]]; then
        print_warning "步骤 $step 不在预定义步骤列表中，但将继续执行"
    fi
    
    print_info "执行kubeasz步骤 $step: ${kubeasz_steps[$step]:-未知步骤}"
    
    # 执行安装步骤
    if execute_with_privileges docker exec -it kubeasz ezctl setup "$cluster_name" "$step"; then
        print_success "kubeasz步骤 $step 执行完成"
        return 0
    else
        print_error "kubeasz步骤 $step 执行失败"
        return 1
    fi
}

# 执行kubeasz分步安装
run_kubeasz_setup() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始执行kubeasz分步安装..."
    
    # 检查kubeasz容器
    if ! check_kubeasz_container; then
        return 1
    fi
    
    # 显示步骤信息
    show_kubeasz_steps
    
    # 确认是否继续
    read -p "是否开始执行kubeasz安装? (y/n, 默认y): " confirm_start
    if [[ $confirm_start =~ ^[Nn]$ ]]; then
        print_info "用户取消安装"
        exit 0;
        return 0
    fi
    
    # 定义安装步骤顺序
    local steps=("01" "02" "03" "04" "05" "06" "07")
    
    # 执行每个步骤
    for step in "${steps[@]}"; do
        echo ""
        print_info "=== 开始执行步骤 $step: ${kubeasz_steps[$step]} ==="
        
        # 执行当前步骤
        if ! run_kubeasz_single_step "$cluster_name" "$step"; then
            print_error "步骤 $step 执行失败，安装中止"
            exit 1;
            
            # # 询问是否继续执行后续步骤
            # read -p "是否跳过此步骤继续执行后续步骤? (y/n, 默认n): " skip_step
            # if [[ ! $skip_step =~ ^[Yy]$ ]]; then
            #     return 1
            # else
            #     print_warning "跳过步骤 $step，继续执行后续步骤"
            #     continue
            # fi
        fi
        
        # 步骤间暂停（可选）
        # if [[ "$step" != "07" ]]; then
            echo ""
            # read -p "步骤 $step 完成，按回车继续下一步骤..." dummy
            echo  "步骤 $step 完成"
        # fi
    done
    
    echo ""
    print_success "所有kubeasz安装步骤执行完成！"
    
    # 显示完成信息
    echo ""
    echo "=================================================="
    echo "          K8s集群安装完成"
    echo "=================================================="
    echo ""
    echo "集群信息:"
    echo "  - 集群名称: $cluster_name"
    echo "  - 域名: $QN_DOMAIN"
    echo "  - Master节点: ${#master_ips[@]} 个"
    echo "  - Worker节点: ${#worker_ips[@]} 个"
    echo ""
    echo "下一步操作:"
    echo "  1. 检查集群状态: docker exec -it kubeasz ezctl status $cluster_name"
    echo "  2. 查看集群节点: docker exec -it kubeasz kubectl get nodes"
    echo "  3. 查看所有Pod: docker exec -it kubeasz kubectl get pods -A"
    echo ""
    
    return 0
}

# 检查集群状态
check_cluster_status() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "检查集群 $cluster_name 状态..."
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    if execute_with_privileges docker exec -it kubeasz ezctl status "$cluster_name"; then
        print_success "集群状态检查完成"
        return 0
    else
        print_error "集群状态检查失败"
        return 1
    fi
}

# 显示集群信息
show_cluster_info() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "显示集群 $cluster_name 信息..."
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群节点信息"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get nodes -o wide; then
        print_error "获取节点信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群Pod状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get pods -A; then
        print_error "获取Pod信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群服务状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -it kubeasz kubectl get svc -A; then
        print_error "获取服务信息失败"
        return 1
    fi
    
    return 0
}
