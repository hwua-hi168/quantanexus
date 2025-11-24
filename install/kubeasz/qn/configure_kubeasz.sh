#!/bin/bash

# kubeasz配置模块

# 配置kubeasz

configure_kubeasz() {
    print_info "开始配置kubeasz..."
    cd $SCRIPT_DIR
    
    # 1. 定义并检查配置文件路径
    # 假设配置文件在当前脚本目录下，或者你可以指定绝对路径
    local config_file=".k8s_cluster_config"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "配置文件不存在: $config_file"
        print_error "请先运行收集信息脚本生成配置。"
        return 1
    fi
    
    # 2. 加载配置文件 (Source)
    print_info "加载集群配置: $config_file"
    source "$config_file"
    
    # 3. 恢复环境 (将配置文件中的字符串恢复为脚本需要的数组结构)
    # 这是为了让 generate_hosts_file 能正确生成 etcd/master/node 的拓扑结构
    
    # 恢复普通数组
    all_ips=($all_ips_str)
    etcd_ips=($etcd_ips_str)
    master_ips=($master_ips_str)
    worker_ips=($worker_ips_str)
    
    # 恢复关联数组 node_names (格式: "IP:NAME IP:NAME")
    declare -gA node_names
    for mapping in $node_names_mappings; do
        local ip="${mapping%%:*}"
        local name="${mapping##*:}"
        node_names["$ip"]="$name"
    done

    # ----------------------------------------------------
    # 基础检查逻辑 (保持不变)
    # ----------------------------------------------------
    if [[ ! -d "quantanexus-main" ]]; then
        print_error "quantanexus源码目录不存在，请先下载源码"
        return 1
    fi
    
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    local cluster_name="k8s-qn-01"
    local kubeasz_cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    local hosts_file="$kubeasz_cluster_dir/hosts"
    
    print_info "配置集群 $cluster_name ..."
    
    if [[ ! -f "$hosts_file" ]]; then
        print_error "hosts文件不存在: $hosts_file"
        return 1
    fi
    
    # 备份原文件
    execute_with_privileges cp "$hosts_file" "$hosts_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # ----------------------------------------------------
    # 生成拓扑结构 (仅为了获取 [etcd]/[kube_master] 等部分的正确格式)
    # ----------------------------------------------------
    local temp_config_file=$(mktemp)
    generate_hosts_file "$temp_config_file"
    
    # 提取各部分的实际内容
    local etcd_content=$(sed -n '/^\[etcd\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local master_content=$(sed -n '/^\[kube_master\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local worker_content=$(sed -n '/^\[kube_node\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    
    # ==========================================
    # [变量处理区域] 从已加载的配置中构建 Map
    # ==========================================
    
    # 定义你要同步的所有变量名 (对应 .k8s_cluster_config 中的 Key)
    # 你可以随时在这里添加新变量，如 "NEW_VAR_1"
    local vars_to_sync=("QN_DOMAIN" "IMAGE_REGISTRY" "QN_CS_DOMAIN")
    
    declare -A var_map
    
    print_info "从配置文件提取变量..."
    for var_name in "${vars_to_sync[@]}"; do
        # 使用 Bash 间接引用 ${!var_name} 获取变量的值
        local var_value="${!var_name}"
        
        if [[ -n "$var_value" ]]; then
            # 构建 key="value" 格式的字符串
            var_map["$var_name"]="${var_name}=\"${var_value}\""
            echo "  [Add] $var_name -> ${var_value}"
        else
            echo "  [Skip] 变量 $var_name 在配置文件中为空或不存在"
        fi
    done

    # ----------------------------------------------------
    # 文件替换逻辑 (核心循环，保持幂等性)
    # ----------------------------------------------------
    local temp_updated_file=$(mktemp)
    local in_section=""
    local section_updated=false
    
    while IFS= read -r line; do
        # 1. 检测 Section 进入
        if [[ "$line" =~ ^\[etcd\]$ ]]; then in_section="etcd"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[kube_master\]$ ]]; then in_section="master"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[kube_node\]$ ]]; then in_section="worker"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[all:vars\]$ ]]; then in_section="vars"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        
        # 2. 检测 Section 退出
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ -n "$in_section" ]]; then in_section=""; fi
        
        # 3. 处理各个 Section
        case "$in_section" in
            "etcd")
                if [[ "$section_updated" == false ]]; then echo "$etcd_content" >> "$temp_updated_file"; section_updated=true; fi
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then echo "$line" >> "$temp_updated_file"; fi
                ;;
            "master")
                if [[ "$section_updated" == false ]]; then echo "$master_content" >> "$temp_updated_file"; section_updated=true; fi
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then echo "$line" >> "$temp_updated_file"; fi
                ;;
            "worker")
                if [[ "$section_updated" == false ]]; then echo "$worker_content" >> "$temp_updated_file"; section_updated=true; fi
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then echo "$line" >> "$temp_updated_file"; fi
                ;;
            "vars")
                # 动态处理 var_map 中的变量
                local is_managed_var=false
                for var_key in "${!var_map[@]}"; do
                    # 如果行以 "VAR=" 开头
                    if [[ "$line" =~ ^$var_key= ]]; then
                        echo "${var_map[$var_key]}" >> "$temp_updated_file" # 写入新值
                        unset var_map["$var_key"] # 从待处理列表中移除 (幂等性)
                        is_managed_var=true
                        break
                    fi
                done
                # 如果不是我们要管理的变量，原样保留
                if [[ "$is_managed_var" == false ]]; then echo "$line" >> "$temp_updated_file"; fi
                ;;
            *)
                echo "$line" >> "$temp_updated_file" ;;
        esac
    done < "$hosts_file"
    
    # 4. 追加新增变量 (处理 var_map 中剩余的项)
    if [ ${#var_map[@]} -gt 0 ]; then
        print_info "追加新增变量到 [all:vars]..."
        # 确保有 [all:vars] 标签
        if ! grep -q "\[all:vars\]" "$temp_updated_file"; then
            echo -e "\n[all:vars]" >> "$temp_updated_file"
        fi
        
        # 找到 [all:vars] 的行号
        local line_num=$(grep -n "\[all:vars\]" "$temp_updated_file" | tail -n 1 | cut -d: -f1)
        
        # 倒序插入或直接追加，这里选择追加到临时文件对应位置
        # 使用 sed 在 [all:vars] 后面一行行插入稍微麻烦，不如直接追加到文件末尾？
        # 为了美观，我们使用 sed 插在 [all:vars] 下面
        if [[ -n "$line_num" ]]; then
             for var_key in "${!var_map[@]}"; do
                sed -i "${line_num}a\\${var_map[$var_key]}" "$temp_updated_file"
             done
        fi
    fi
    
    # 覆盖原文件
    if execute_with_privileges cp "$temp_updated_file" "$hosts_file"; then
        print_success "hosts文件更新完成"
    else
        print_error "hosts文件更新失败"
        rm -f "$temp_config_file" "$temp_updated_file"
        return 1
    fi
    
    rm -f "$temp_config_file" "$temp_updated_file"
    
    # 显示结果
    print_info "更新后的 Vars 部分:"
    grep -A 10 "\[all:vars\]" "$hosts_file"
    
    # 同步代码 (保持不变)
    print_info "同步自定义代码到kubeasz..."
    execute_with_privileges rsync -a quantanexus-main/install/kubeasz/playbooks/ /etc/kubeasz/playbooks/
    execute_with_privileges rsync -a quantanexus-main/install/kubeasz/roles/ /etc/kubeasz/roles/
    
    return 0
}