#!/bin/bash

# kubeasz配置模块

# 配置kubeasz
configure_kubeasz() {
    print_info "开始配置kubeasz..."
    cd $SCRIPT_DIR
    
    # 检查quantanexus源码是否存在
    if [[ ! -d "quantanexus-main" ]]; then
        print_error "quantanexus源码目录不存在，请先下载源码"
        return 1
    fi
    
    # 检查kubeasz容器是否运行
    if ! docker ps | grep -q kubeasz; then
        print_error "kubeasz容器未运行，请先安装kubeasz"
        return 1
    fi
    
    local cluster_name="k8s-qn-01"
    local kubeasz_cluster_dir="/etc/kubeasz/clusters/$cluster_name"
    local hosts_file="$kubeasz_cluster_dir/hosts"
    
    print_info "配置集群 $cluster_name ..."
    
    # 检查hosts文件是否存在
    if [[ ! -f "$hosts_file" ]]; then
        print_error "hosts文件不存在: $hosts_file"
        return 1
    fi
    
    # 备份原文件
    print_info "备份原hosts文件..."
    execute_with_privileges cp "$hosts_file" "$hosts_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 生成新的配置内容
    local temp_config_file=$(mktemp)
    generate_hosts_file "$temp_config_file"
    
    # 提取各部分的实际内容（去掉空行和注释）
    local etcd_content=$(sed -n '/^\[etcd\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local master_content=$(sed -n '/^\[kube_master\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local worker_content=$(sed -n '/^\[kube_node\]/,/^$/p' "$temp_config_file" | grep -v '^#' | grep -v '^$' | tail -n +2)
    local qn_domain=$(grep "QN_DOMAIN=" "$temp_config_file")
    local image_registry=$(grep "IMAGE_REGISTRY=" "$temp_config_file")  # 新增镜像仓库变量提取
    
    print_info "提取的配置内容:"
    echo "etcd: $etcd_content"
    echo "master: $master_content" 
    echo "worker: $worker_content"
    echo "domain: $qn_domain"
    echo "image_registry: $image_registry"
    
    # 创建临时文件用于存储更新后的内容
    local temp_updated_file=$(mktemp)
    
    # 使用更简单的方法处理文件
    local in_section=""
    local section_updated=false
    local image_registry_added=false  # 添加变量跟踪IMAGE_REGISTRY是否已添加
    
    while IFS= read -r line; do
        # 检测是否进入我们关心的section
        if [[ "$line" =~ ^\[etcd\]$ ]]; then
            in_section="etcd"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[kube_master\]$ ]]; then
            in_section="master"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[kube_node\]$ ]]; then
            in_section="worker"
            section_updated=false
            echo "$line" >> "$temp_updated_file"
            continue
        elif [[ "$line" =~ ^\[all:vars\]$ ]]; then
            in_section="vars"
            section_updated=false
            image_registry_added=false  # 重置IMAGE_REGISTRY添加状态
            echo "$line" >> "$temp_updated_file"
            continue
        fi
        
        # 如果遇到下一个section，重置状态
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ -n "$in_section" ]]; then
            in_section=""
        fi
        
        # 处理各个section的内容
        case "$in_section" in
            "etcd")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的etcd内容
                    echo "$etcd_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的etcd内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "master")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的master内容
                    echo "$master_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的master内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "worker")
                if [[ "$section_updated" == false ]]; then
                    # 插入新的worker内容
                    echo "$worker_content" >> "$temp_updated_file"
                    section_updated=true
                fi
                # 跳过原有的worker内容（空行和注释除外）
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^# ]]; then
                    echo "$line" >> "$temp_updated_file"
                fi
                ;;
            "vars")
                # 处理QN_DOMAIN变量，确保幂等性
                if [[ "$line" =~ ^QN_DOMAIN= ]]; then
                    # 如果还没有更新QN_DOMAIN，则替换现有的QN_DOMAIN
                    if [[ "$section_updated" == false ]]; then
                        echo "$qn_domain" >> "$temp_updated_file"
                        section_updated=true
                    fi
                    # 如果已经更新过QN_DOMAIN，则跳过重复的定义
                    continue
                # 处理IMAGE_REGISTRY变量
                elif [[ "$line" =~ ^IMAGE_REGISTRY= ]]; then
                    # 如果还没有更新IMAGE_REGISTRY，则替换现有的IMAGE_REGISTRY
                    if [[ "$image_registry_added" == false ]]; then
                        echo "$image_registry" >> "$temp_updated_file"
                        image_registry_added=true
                    fi
                    # 如果已经更新过IMAGE_REGISTRY，则跳过重复的定义
                    continue
                # 处理CLUSTER_NETWORK变量，将其从calico改为cilium
                elif [[ "$line" =~ ^CLUSTER_NETWORK= ]]; then
                    echo "CLUSTER_NETWORK=\"cilium\"" >> "$temp_updated_file"
                    section_updated=true
                else
                    echo "$line" >> "$temp_updated_file"
                    # 如果没有找到QN_DOMAIN，在适当位置添加
                    if [[ "$section_updated" == false ]] && [[ "$line" =~ ^#.*Main.Variables ]]; then
                        echo "$qn_domain" >> "$temp_updated_file"
                        section_updated=true
                        # 如果还没有添加IMAGE_REGISTRY，则也添加
                        if [[ "$image_registry_added" == false ]]; then
                            echo "$image_registry" >> "$temp_updated_file"
                            image_registry_added=true
                        fi
                    fi
                fi
                ;;
            *)
                # 不在我们关心的section中，直接输出
                echo "$line" >> "$temp_updated_file"
                ;;
        esac
    done < "$hosts_file"
    
    # 如果QN_DOMAIN在vars section中还没有被处理，添加到vars section末尾
    if grep -q "\[all:vars\]" "$temp_updated_file" && ! grep -q "QN_DOMAIN=" "$temp_updated_file"; then
        sed -i '/\[all:vars\]/a\'"$qn_domain" "$temp_updated_file"
    fi
    
    # 如果IMAGE_REGISTRY在vars section中还没有被处理，添加到vars section末尾
    if grep -q "\[all:vars\]" "$temp_updated_file" && ! grep -q "IMAGE_REGISTRY=" "$temp_updated_file"; then
        sed -i '/\[all:vars\]/a\'"$image_registry" "$temp_updated_file"
    fi
    
    # 替换原文件
    if execute_with_privileges cp "$temp_updated_file" "$hosts_file"; then
        print_success "hosts文件更新完成"
    else
        print_error "hosts文件更新失败"
        rm -f "$temp_config_file" "$temp_updated_file"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$temp_config_file" "$temp_updated_file"
    
    # 显示更新后的文件内容
    print_info "更新后的hosts文件内容:"
    execute_with_privileges cat "$hosts_file"
    
    # 同步自定义的代码到kubeasz中
    print_info "同步自定义代码到kubeasz..."
    
    if execute_with_privileges rsync -a quantanexus-main/install/test/kubeasz/playbooks/ /etc/kubeasz/playbooks/ && \
       execute_with_privileges rsync -a quantanexus-main/install/test/kubeasz/roles/ /etc/kubeasz/roles/; then
        print_success "自定义代码已同步到kubeasz"
    else
        print_error "同步自定义代码失败"
        return 1
    fi
    
    print_success "kubeasz配置完成"
    return 0
}