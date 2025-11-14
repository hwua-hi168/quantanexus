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
    
    # 尝试通过镜像代理下载
    print_info "尝试通过镜像代理下载..."
    # 下载main分支以确保解压后目录名为quantanexus-main
    # if wget -O main.zip "https://hub.gitmirror.com/https://github.com/hwua-hi168/quantanexus/archive/refs/heads/main.zip"; then
    if wget -O main.zip "https://hub.gitmirror.com/https://github.com/hwua-hi168/quantanexus/archive/refs/tags/v0.0.10.zip"; then
        print_success "通过镜像代理下载成功"
    else
        print_warning "镜像代理下载失败，尝试通过源站下载..."
        # 镜像下载失败，尝试源站下载
        if wget -O main.zip "https://github.com/hwua-hi168/quantanexus/archive/refs/heads/main.zip"; then
            print_success "通过源站下载成功"
        else
            print_error "源码下载失败"
            return 1
        fi
    fi
    
    # 解压文件
    print_info "解压源码文件..."
    if unzip main.zip; then
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
        # 清理下载的zip文件
        rm -f main.zip
        return 0
    else
        print_error "源码解压失败"
        return 1
    fi
}
