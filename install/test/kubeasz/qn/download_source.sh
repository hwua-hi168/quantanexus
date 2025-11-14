#!/bin/bash

# 源码下载模块

# 下载Quantanexus源码
download_source_code() {
    print_info "检查Quantanexus源码..."
    
    # 检查目录是否已存在
    if [[ -d "quantanexus-main" ]]; then
        print_success "Quantanexus源码目录已存在，跳过下载"
        return 0
    fi
    
    print_info "开始下载Quantanexus源码..."
    
    # 获取最新的标签
    print_info "获取Quantanexus最新标签..."
    quantanexus_version=$(curl -s "https://api.github.com/repos/hwua-hi168/quantanexus/tags" | grep -o '"name": "[^"]*' | head -1 | cut -d'"' -f4)
    
    if [[ -z "$quantanexus_version" ]]; then
        print_error "无法获取最新标签"
        exit 1;
    else
        print_success "获取到最新标签: $quantanexus_version"
    fi
    
    # 尝试通过镜像代理下载
    print_info "尝试通过镜像代理下载..."
    # 下载release tar.gz包
    if wget -O "quantanexus-${quantanexus_version}.tar.gz" "https://hub.gitmirror.com/https://github.com/hwua-hi168/quantanexus/releases/download/${quantanexus_version}/quantanexus-${quantanexus_version}.tar.gz"; then
        print_success "通过镜像代理下载成功"
    else
        print_warning "镜像代理下载失败，尝试通过源站下载..."
        # 镜像下载失败，尝试源站下载
        if wget -O "quantanexus-${quantanexus_version}.tar.gz" "https://github.com/hwua-hi168/quantanexus/releases/download/${quantanexus_version}/quantanexus-${quantanexus_version}.tar.gz"; then
            print_success "通过源站下载成功"
        else
            print_error "源码下载失败"
            return 1
        fi
    fi
    
    # 解压文件
    print_info "解压源码文件..."
    if tar -xzf "quantanexus-${quantanexus_version}.tar.gz"; then
        # 修改解压后的目录名确保为quantanexus-main
        if [[ -d "quantanexus-main" ]]; then
            print_success "源码解压成功"
        else
             # 如果目录名不是quantanexus-main，则重命名
            dir_name=$(ls -d quantanexus-* | head -n 1)
            if [[ -n "$dir_name" && -d "$dir_name" ]]; then
                mv "$dir_name" quantanexus-main
                print_success "源码解压并重命名为quantanexus-main"
            else
                print_error "无法找到解压后的目录"
                return 1
            fi
        fi
        # 清理下载的tar.gz文件
        rm -f "quantanexus-${quantanexus_version}.tar.gz"
        return 0
    else
        print_error "源码解压失败"
        return 1
    fi
}