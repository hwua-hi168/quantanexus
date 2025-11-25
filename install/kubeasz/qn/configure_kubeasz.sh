#!/bin/bash

# kubeasz配置模块

# 配置kubeasz

configure_kubeasz() {
    print_info "开始配置kubeasz..."
    cd $SCRIPT_DIR
    
    # 1. 定义并检查配置文件路径
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
    all_ips=($all_ips_str)
    etcd_ips=($etcd_ips_str)
    master_ips=($master_ips_str)
    worker_ips=($worker_ips_str)
    
    declare -gA node_names
    for mapping in $node_names_mappings; do
        local ip="${mapping%%:*}"
        local name="${mapping##*:}"
        node_names["$ip"]="$name"
    done

    # ----------------------------------------------------
    # 基础检查逻辑
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
    local global_config_file="$kubeasz_cluster_dir/config.yml" # 新增：全局配置文件路径
    
    print_info "配置集群 $cluster_name ..."
    
    if [[ ! -f "$hosts_file" ]]; then
        print_error "hosts文件不存在: $hosts_file"
        return 1
    fi
    
    # 备份 hosts 原文件
    execute_with_privileges cp "$hosts_file" "$hosts_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # ----------------------------------------------------
    # 生成拓扑结构 (仅为了获取 [etcd]/[kube_master] 等部分的正确格式)
    # ----------------------------------------------------
    local temp_config_file=$(mktemp)
    generate_hosts_file "$temp_config_file"
    
    local etcd_content=$(sed -n '/^\[etcd\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local master_content=$(sed -n '/^\[kube_master\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local worker_content=$(sed -n '/^\[kube_node\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    
    # ==========================================
    # [变量定义区域] 
    # ==========================================
    # 定义你要同步的所有变量名
    local vars_to_sync=("QN_DOMAIN" "IMAGE_REGISTRY" "QN_CS_DOMAIN" "NEW_VAR_1")
    
    declare -A var_map
    
    print_info "从配置文件提取变量..."
    for var_name in "${vars_to_sync[@]}"; do
        local var_value="${!var_name}"
        if [[ -n "$var_value" ]]; then
            # hosts 文件使用 key="value" 格式
            var_map["$var_name"]="${var_name}=\"${var_value}\""
            echo "  [Map] $var_name -> ${var_value}"
        else
            echo "  [Skip] 变量 $var_name 为空"
        fi
    done

    # ----------------------------------------------------
    # hosts 文件更新逻辑 (幂等性)
    # ----------------------------------------------------
    local temp_updated_file=$(mktemp)
    local in_section=""
    local section_updated=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[etcd\]$ ]]; then in_section="etcd"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[kube_master\]$ ]]; then in_section="master"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[kube_node\]$ ]]; then in_section="worker"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        if [[ "$line" =~ ^\[all:vars\]$ ]]; then in_section="vars"; section_updated=false; echo "$line" >> "$temp_updated_file"; continue; fi
        
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ -n "$in_section" ]]; then in_section=""; fi
        
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
                local is_managed_var=false
                for var_key in "${!var_map[@]}"; do
                    # 检查 hosts 变量格式 (KEY=VALUE)
                    if [[ "$line" =~ ^$var_key= ]]; then
                        echo "${var_map[$var_key]}" >> "$temp_updated_file"
                        unset var_map["$var_key"]
                        is_managed_var=true
                        break
                    fi
                done
                if [[ "$is_managed_var" == false ]]; then echo "$line" >> "$temp_updated_file"; fi
                ;;
            *)
                echo "$line" >> "$temp_updated_file" ;;
        esac
    done < "$hosts_file"
    
    # 追加新增变量
    if [ ${#var_map[@]} -gt 0 ]; then
        if ! grep -q "\[all:vars\]" "$temp_updated_file"; then echo -e "\n[all:vars]" >> "$temp_updated_file"; fi
        local line_num=$(grep -n "\[all:vars\]" "$temp_updated_file" | tail -n 1 | cut -d: -f1)
        if [[ -n "$line_num" ]]; then
             for var_key in "${!var_map[@]}"; do
                sed -i "${line_num}a\\${var_map[$var_key]}" "$temp_updated_file"
             done
        fi
    fi
    
    # 覆盖 hosts 文件
    if execute_with_privileges cp "$temp_updated_file" "$hosts_file"; then
        print_success "hosts文件更新完成"
    else
        print_error "hosts文件更新失败"
        rm -f "$temp_config_file" "$temp_updated_file"
        return 1
    fi
    
    rm -f "$temp_config_file" "$temp_updated_file"

    # ==========================================
    # [Config清理区域] 检查 config 文件并注释掉重复变量
    # ==========================================
    if [[ -f "$global_config_file" ]]; then
        print_info "检查 config 文件中的冲突变量: $global_config_file"
        
        # 1. 备份 config 文件
        execute_with_privileges cp "$global_config_file" "$global_config_file.backup.$(date +%Y%m%d_%H%M%S)"
        
        local config_changed=false
        
        # 2. 遍历 vars_to_sync，如果在 config 文件中发现则注释掉
        for var_key in "${vars_to_sync[@]}"; do
            # 匹配行首为 KEY: 的行 (忽略前面的空格)
            if grep -q "^[[:space:]]*$var_key:" "$global_config_file"; then
                print_warning "  在 config 中发现冲突变量: $var_key -> 已注释"
                
                # 使用 sed 在行首添加注释符号 #
                # 匹配：行首(任意空格)KEY:
                execute_with_privileges sed -i "s/^[[:space:]]*$var_key:/# &/" "$global_config_file"
                config_changed=true
            fi
        done
        
        if [[ "$config_changed" == true ]]; then
            print_success "config 文件清理完成 (冲突变量已注释)"
        else
            print_info "config 文件无需修改 (未发现冲突变量)"
        fi
    else
        print_warning "未找到全局配置文件: $global_config_file (跳过清理)"
    fi

    # ----------------------------------------------------
    # 同步代码
    # ----------------------------------------------------
    print_info "同步自定义代码到kubeasz..."
    execute_with_privileges rsync -a quantanexus-main/install/kubeasz/playbooks/ /etc/kubeasz/playbooks/
    execute_with_privileges rsync -a quantanexus-main/install/kubeasz/roles/ /etc/kubeasz/roles/
    
    print_success "kubeasz配置完成"
    return 0
}