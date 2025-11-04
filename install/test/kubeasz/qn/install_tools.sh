#!/bin/bash

# 工具安装模块

# 检查并安装所需的所有工具
install_required_commands() {
    print_info "检查所需命令工具..."
    
    local missing_tools=()
    # 添加 rsync 到必需工具列表
    local required_tools=("ssh" "sshpass" "ansible" "ssh-keygen" "tr" "fold" "head" "cat" "sed" "unzip" "rsync")
    
    # 检查每个必需的工具
    for tool in "${required_tools[@]}"; do
        if ! check_command "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    # 如果没有缺失的工具，则返回
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_success "所有必需的命令工具均已安装"
        return 0
    fi
    
    print_warning "检测到缺失的工具: ${missing_tools[*]}"
    
    # 检查是否有足够权限安装软件包
    if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
        print_error "权限不足且未找到sudo命令，请以root用户运行此脚本或使用sudo"
        return 1
    fi
    
    # 安装缺失的工具
    if command -v apt-get &> /dev/null; then
        print_info "使用 apt-get 安装缺失的工具..."
        if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
            sudo apt-get update
        else
            apt-get update
        fi
        
        local packages_to_install=()
        
        # 根据缺失的工具确定需要安装的包
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "ssh") packages_to_install+=("openssh-client") ;;
                "sshpass") packages_to_install+=("sshpass") ;;
                "ansible") packages_to_install+=("ansible") ;;
                "ssh-keygen") packages_to_install+=("openssh-client") ;;
                "unzip") packages_to_install+=("unzip") ;;
            esac
        done
        
        # 添加通用工具包和 rsync
        packages_to_install+=("coreutils" "sed" "rsync")
        
        # 去重
        local unique_packages=($(echo "${packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#unique_packages[@]} -gt 0 ]; then
            if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                sudo apt-get install -y "${unique_packages[@]}"
            else
                apt-get install -y "${unique_packages[@]}"
            fi
        fi
        
    elif command -v yum &> /dev/null; then
        print_info "使用 yum 安装缺失的工具..."
        local packages_to_install=()
        
        # 根据缺失的工具确定需要安装的包
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "ssh") packages_to_install+=("openssh-clients") ;;
                "sshpass") packages_to_install+=("sshpass") ;;
                "ansible") 
                    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                        sudo yum install -y epel-release
                    else
                        yum install -y epel-release
                    fi
                    packages_to_install+=("ansible")
                    ;;
                "ssh-keygen") packages_to_install+=("openssh") ;;
                "unzip") packages_to_install+=("unzip") ;;
            esac
        done
        
        # 添加通用工具包和 rsync
        packages_to_install+=("coreutils" "sed" "rsync")
        
        # 去重
        local unique_packages=($(echo "${packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        
        if [ ${#unique_packages[@]} -gt 0 ]; then
            if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
                sudo yum install -y "${unique_packages[@]}"
            else
                yum install -y "${unique_packages[@]}"
            fi
        fi
    else
        print_error "不支持的包管理器，请手动安装以下工具: ${missing_tools[*]}"
        return 1
    fi
    
    # 再次验证所有工具是否已安装
    local still_missing=()
    for tool in "${missing_tools[@]}"; do
        if ! check_command "$tool"; then
            still_missing+=("$tool")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        print_error "以下工具安装失败或仍缺失: ${still_missing[*]}"
        return 1
    fi
    
    print_success "所有必需的命令工具安装完成"
    return 0
}