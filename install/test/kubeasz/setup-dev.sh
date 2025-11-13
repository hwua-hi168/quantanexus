#!/bin/bash

# prepare kubeasz dev environment 

python3 -m venv ~/.venv/myenv
# create the venv evironment 
source ~/.venv/myenv/bin/activate
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

#upgrade the pip3
python3 -m pip install -U pip
#
pip3 install kubernetes  ansible

# 脚本所在目录（绝对路径）
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# 1. 若 /etc/kubeasz 存在，则带时间戳备份
if [ -e /etc/kubeasz ]; then
    ts=$(date +%Y%m%d-%H%M%S)
    bak="/etc/kubeasz.bak.${ts}"
    mv /etc/kubeasz "${bak}"
    echo "Backed up /etc/kubeasz -> ${bak}"
fi

# 2. 建立新软链接（此时 /etc/kubeasz 不存在）
ln -sfn "${SCRIPT_DIR}" /etc/kubeasz

# 3. 如果备份目录里有 clusters，就复制回软链接目标（即脚本目录）
if [ -d "${bak}/clusters" ]; then
    cp -a "${bak}/clusters" "${SCRIPT_DIR}/"
    echo "Restored ${bak}/clusters -> ${SCRIPT_DIR}/clusters"
fi