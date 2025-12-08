#!/bin/bash
set -euo pipefail
# ----------------------------------------------------------
#  kubeasz 开发环境一键准备脚本（Debian/Ubuntu 完全自动版）
# ----------------------------------------------------------

# 获取 Python 主版本号和小版本号
PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
PY_VERSION="${PY_MAJOR}.${PY_MINOR}"
VENV_DIR="$HOME/.venv/myenv"
NEED_PKG=()

echo "[INFO] 检测到 Python 版本: $PY_VERSION"

# 1. 检测并补全系统依赖
command -v python3 >/dev/null || { echo "[ERROR] 请先安装 python3"; exit 1; }

# 1.1 检测 venv 模块是否可用
if ! python3 -c "import venv" 2>/dev/null; then
    echo "[INFO] venv 模块不可用，需要安装 python3-venv"
    NEED_PKG+=(python3-venv)
fi

# 1.2 检测 ensurepip 是否可用
if ! python3 -c "import ensurepip" 2>/dev/null; then
    echo "[INFO] ensurepip 不可用，需要安装 python3-venv"
    # 在 Ubuntu/Debian 中，ensurepip 包含在 python3-venv 中
    if [[ ! " ${NEED_PKG[@]} " =~ " python3-venv " ]]; then
        NEED_PKG+=(python3-venv)
    fi
fi

# 1.3 检测 pip 是否可用
if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "[INFO] pip 不可用，需要安装 python3-pip"
    NEED_PKG+=(python3-pip)
fi

# 1.4 检测 distutils 是否可用
if ! python3 -c "import distutils" 2>/dev/null; then
    echo "[INFO] distutils 不可用，可能需要安装 python3-distutils"
    # 在某些系统中，distutils 可能已经包含或不需要单独安装
    # 先尝试安装，如果失败也没关系
fi

# 安装缺失的包
if [[ ${#NEED_PKG[@]} -gt 0 ]]; then
    echo "[INFO] 缺少系统包：${NEED_PKG[*]}，即将自动安装 ..."
    sudo apt update
    
    # 尝试安装所有需要的包
    for pkg in "${NEED_PKG[@]}"; do
        echo "[INFO] 尝试安装: $pkg"
        if sudo apt install -y "$pkg" 2>/dev/null; then
            echo "[OK] 成功安装: $pkg"
        else
            # 如果特定版本包不存在，尝试通用包名
            if [[ "$pkg" == "python3-venv" ]]; then
                echo "[INFO] 尝试安装通用 python3-venv 包..."
                sudo apt install -y python3-venv
            fi
        fi
    done
fi

# 2. 检查是否安装了必要的包，如果还没有则尝试直接安装
if ! python3 -c "import venv" 2>/dev/null; then
    echo "[WARN] venv 模块仍然不可用，尝试直接安装..."
    sudo apt install -y python3-venv
fi

# 3. 建立/激活虚拟环境
echo "[INFO] 创建 venv：$VENV_DIR"

# 清理可能存在的失败创建
if [[ -d "$VENV_DIR" ]]; then
    echo "[INFO] 清理已存在的虚拟环境目录..."
    rm -rf "$VENV_DIR"
fi

# 创建虚拟环境
if ! python3 -m venv "$VENV_DIR"; then
    echo "[ERROR] 创建虚拟环境失败"
    echo "[INFO] 尝试使用 --without-pip 参数创建..."
    python3 -m venv "$VENV_DIR" --without-pip
    if [[ $? -eq 0 ]]; then
        echo "[INFO] 虚拟环境创建成功（不带 pip）"
        # 激活环境并手动安装 pip
        source "$VENV_DIR/bin/activate"
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3
        deactivate
    else
        echo "[ERROR] 虚拟环境创建完全失败，请检查系统环境"
        exit 1
    fi
else
    echo "[OK] 虚拟环境创建成功"
fi

# 4. 激活虚拟环境
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# 5. 配置国内源 & 升级 pip
echo "[INFO] 配置 pip 国内源..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

echo "[INFO] 升级 pip..."
python3 -m pip install -U pip setuptools wheel
echo "[INFO] pip 版本：$(python3 -m pip --version)"

# 6. 安装 Python 依赖
echo "[INFO] 安装 kubernetes 和 ansible..."
pip install kubernetes ansible
echo "[INFO] 核心依赖安装完成"

# 7. 链接 kubeasz 到 /etc/kubeasz
SCRIPT_DIR=$(dirname "$(realpath "$0")")

if [[ -e /etc/kubeasz ]]; then
    if [[ -L /etc/kubeasz ]]; then
        echo "[INFO] /etc/kubeasz 已是一个软链接"
        CURRENT_LINK=$(readlink -f /etc/kubeasz)
        if [[ "$CURRENT_LINK" == "$SCRIPT_DIR" ]]; then
            echo "[INFO] 已经是正确的链接，无需修改"
        else
            ts=$(date +%Y%m%d-%H%M%S)
            bak="/etc/kubeasz.bak.$ts"
            rm /etc/kubeasz
            ln -sfn "$SCRIPT_DIR" /etc/kubeasz
            echo "[INFO] 已更新链接 /etc/kubeasz -> $SCRIPT_DIR"
        fi
    else
        ts=$(date +%Y%m%d-%H%M%S)
        bak="/etc/kubeasz.bak.$ts"
        mv /etc/kubeasz "$bak"
        echo "[INFO] 已备份 /etc/kubeasz -> $bak"
        ln -sfn "$SCRIPT_DIR" /etc/kubeasz
    fi
else
    ln -sfn "$SCRIPT_DIR" /etc/kubeasz
fi

echo "[INFO] /etc/kubeasz -> $SCRIPT_DIR"

# 8. 恢复 clusters（如有）
if [[ -n "${bak:-}" ]] && [[ -d "$bak/clusters" ]]; then
    cp -a "$bak/clusters" "$SCRIPT_DIR/"
    echo "[INFO] 恢复 clusters 目录完成"
fi

EZDOWN_PATH="$SCRIPT_DIR/ezdown"
if [[ -f "$EZDOWN_PATH" ]]; then
    echo "[INFO] ezdown 已存在：$EZDOWN_PATH"
    chmod +x "$EZDOWN_PATH"
else
    echo "[INFO] 正在下载 ezdown ..."
    # 先保证有 jq
    command -v jq >/dev/null || sudo apt install -y jq
    # 取最新 tag 并下载
    LATEST_TAG=$(curl -s "https://api.github.com/repos/hwua-hi168/quantanexus/releases/latest" | jq -r .tag_name)
    URL="https://github.com/hwua-hi168/quantanexus/releases/download/${LATEST_TAG}/ezdown"
    curl -L "$URL" -o "$EZDOWN_PATH" || { echo "[ERROR] ezdown 下载失败"; exit 1; }
    chmod +x "$EZDOWN_PATH"
    echo "[OK] ezdown 下载完成并已赋可执行权限"
fi
# 9. 打印摘要
cat <<EOF
----------------------------------------------------
kubeasz-dev 环境就绪！

激活 venv:  source $VENV_DIR/bin/activate
当前环境：   $(python3 --version)
pip 版本：   $(python3 -m pip --version | cut -d' ' -f1-2)
ansible 路径：$(command -v ansible)
kubectl 需另行安装，可参考：
  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

虚拟环境目录：$VENV_DIR
kubeasz 目录：$SCRIPT_DIR
----------------------------------------------------
EOF

source /root/.venv/myenv/bin/activate
echo "[OK] 脚本执行完成! 默认已进入Python虚拟环境: source /root/.venv/myenv/bin/activate"