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

# 清理ANSI转义序列（颜色代码等）
clean_ansi_escape() {
    # 移除ANSI转义序列（颜色代码、光标控制等）
    sed -r "s/\x1B\[[0-9;]*[mK]//g" | sed -r "s/\x1B\][0-9;]*//g" | sed -r "s/\x1B\[?[0-9;]*[hHl]//g"
}

# 安全的输出函数
safe_echo() {
    # 确保输出格式正确，添加明确的换行
    echo -e "$@"
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
    echo ""  # 添加空行分隔
    
    # 执行安装步骤 - 添加stderr重定向和输出处理
    # 使用 -i 禁用tty分配，避免进度条导致的格式问题
    if execute_with_privileges docker exec -i kubeasz ezctl setup "$cluster_name" "$step" 2>&1 | \
        while IFS= read -r line; do
            # 清理每行的ANSI转义序列，确保正常显示
            cleaned_line=$(echo "$line" | clean_ansi_escape)
            echo "$cleaned_line"
        done; then
        echo ""  # 步骤完成后添加空行
        print_success "kubeasz步骤 $step 执行完成"
        return 0
    else
        echo ""  # 步骤完成后添加空行
        print_error "kubeasz步骤 $step 执行失败"
        return 1
    fi
}

# 执行kubeasz分步安装
run_kubeasz_setup() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "开始执行kubeasz分步安装..."
    echo ""  # 添加空行分隔
    
    # 检查kubeasz容器
    if ! check_kubeasz_container; then
        return 1
    fi
    
    echo ""  # 添加空行分隔
    
    # 检查集群是否已经存在并且状态正常
    print_info "检查集群 $cluster_name 是否已经存在..."
    if check_cluster_exists "$cluster_name" && check_cluster_status_quiet "$cluster_name"; then
        print_warning "集群 $cluster_name 已经存在并且状态正常，跳过安装"
        show_cluster_info "$cluster_name"
        return 0
    fi
    
    # 显示步骤信息
    show_kubeasz_steps
    
    # 定义安装步骤顺序
    local steps=("01" "02" "03" "04" "05" "06" "07")
    
    # 执行每个步骤
    for step in "${steps[@]}"; do
        echo ""
        echo "=================================================="
        print_info "开始执行步骤 $step: ${kubeasz_steps[$step]}"
        echo "=================================================="
        echo ""
        
        # 执行当前步骤
        if ! run_kubeasz_single_step "$cluster_name" "$step"; then
            print_error "步骤 $step 执行失败，安装中止"
            exit 1;
        fi
        
        # 步骤间添加分隔线
        if [[ "$step" != "07" ]]; then
            echo ""
            echo "--- 步骤 $step 完成，继续下一步 ---"
            sleep 2  # 短暂暂停，让用户有时间查看输出
        fi
    done
    
    echo ""
    echo "=================================================="
    print_success "所有kubeasz安装步骤执行完成！"
    echo "=================================================="
    echo ""
    
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
    echo "  1. 检查集群状态: docker exec -i kubeasz ezctl status $cluster_name"
    echo "  2. 查看集群节点: /opt/kube/bin/kubectl get nodes"
    echo "  3. 查看所有Pod: /opt/kube/bin/kubectl get pods -A"
    echo ""
    
    return 0
}

# 检查集群状态（详细输出）
check_cluster_status() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "检查集群 $cluster_name 状态..."
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    # 尝试静默检查 kubectl 是否能访问集群
    if execute_with_privileges docker exec -i kubeasz /opt/kube/bin/kubectl get nodes >/dev/null 2>&1; then
        print_success "集群状态检查成功"
        # 成功后，调用 show_cluster_info 显示详细信息
        show_cluster_info "$cluster_name"
        return 0
    else
        print_error "集群状态检查失败 (kubectl 无法访问集群或节点)"
        exit 1
        return 1
    fi
}

# 显示集群信息
show_cluster_info() {
    local cluster_name="${1:-k8s-qn-01}"
    
    print_info "显示集群 $cluster_name 信息..."
    echo ""  # 添加空行分隔
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    echo "=================================================="
    echo "          集群节点信息"
    echo "=================================================="
    # 确保 kubectl 命令在 kubeasz 容器内执行，使用 -i 避免tty问题
    if ! execute_with_privileges docker exec -i kubeasz /usr/bin/kubectl get nodes -o wide; then
        print_error "获取节点信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群Pod状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -i kubeasz /usr/bin/kubectl get pods -A; then
        print_error "获取Pod信息失败"
        return 1
    fi
    
    echo ""
    echo "=================================================="
    echo "          集群服务状态"
    echo "=================================================="
    if ! execute_with_privileges docker exec -i kubeasz /usr/bin/kubectl get svc -A; then
        print_error "获取服务信息失败"
        return 1
    fi
    
    return 0
}

# 检查集群是否存在
check_cluster_exists() {
    local cluster_name="${1:-k8s-qn-01}"
    
    if execute_with_privileges docker exec -i kubeasz ezctl list 2>/dev/null | grep -q "$cluster_name"; then
        return 0
    else
        return 1
    fi
}

# 静默检查集群状态(无输出)
check_cluster_status_quiet() {
    local cluster_name="${1:-k8s-qn-01}"
    
    if ! check_kubeasz_container; then
        return 1
    fi
    
    # 使用 'kubectl get nodes' 检查集群是否已部署并可用
    if execute_with_privileges docker exec -i kubeasz kubectl get nodes >/dev/null 2>&1; then
        echo '成功: 集群已部署且可用'
        return 0 # 成功: 集群已部署且可用
    else
        echo '集群未部署或不可用'
        return 1 # 失败: 集群未部署或不可用
    fi
}