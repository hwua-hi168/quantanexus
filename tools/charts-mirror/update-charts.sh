#!/bin/bash

set -e

# --- 配置变量 ---
REPO_NAME="quantanexus/helm"
# REGISTRY="harbor.hi168.com"
REGISTRY="registry.cn-hangzhou.aliyuncs.com"
if [[ -z $TAG ]]; then
  TAG="1.0.18"
else
  TAG="$1"
fi

CHART_DESTINATION="charts" # 下载 charts 的目标目录
CHART_FILE="charts.csv"   # 包含 charts 列表的 CSV 文件名
QUANTANEXUS_REPO="git@github.com:hwua-hi168/quantanexus.git"
QUANTANEXUS_TAG="${2:-main}"  # 支持从命令行参数获取 tag，默认 main

echo "=== Updating Helm Charts ==="

# 1. 检查 CSV 文件是否存在
if [ ! -f "$CHART_FILE" ]; then
    echo "Error: Chart list file '$CHART_FILE' not found." >&2
    exit 1
fi

# 确保 charts 目录存在
mkdir -p "$CHART_DESTINATION"

# --- 清空 charts 目录以确保只包含最新的版本 ---
# echo "Clearing old charts from $CHART_DESTINATION/..."
# rm -rf "$CHART_DESTINATION"/*.tgz

# --- 克隆并打包 quantanexus 仓库中的 charts ---
echo "=== Processing Quantanexus Charts ==="

QUANTANEXUS_TEMP_DIR="quantanexus-temp"

# 清理临时目录
if [ -d "$QUANTANEXUS_TEMP_DIR" ]; then
    echo "Removing existing temporary directory..."
    rm -rf "$QUANTANEXUS_TEMP_DIR"
fi

# 克隆仓库
echo "Cloning quantanexus repository (tag: $QUANTANEXUS_TAG)..."
git clone --branch "$QUANTANEXUS_TAG" --depth 1 "$QUANTANEXUS_REPO" "$QUANTANEXUS_TEMP_DIR"

cd "$QUANTANEXUS_TEMP_DIR"

# 打包 quantanexus-cs (原 quantanexus-cluster-service)
if [ -d "quantanexus-cs" ]; then
    echo "-> Packaging quantanexus-cs..."
    cd quantanexus-cs
    helm package .
    PACKAGED_FILE=$(ls *.tgz | head -1)
    if [ -n "$PACKAGED_FILE" ]; then
        mv "$PACKAGED_FILE" ../../"$CHART_DESTINATION"/
        echo "   Moved $PACKAGED_FILE to charts directory"
    fi
    cd ..
else
    echo "Warning: quantanexus-cs directory not found"
fi

# 打包 quantanexus-mgr
if [ -d "quantanexus-mgr" ]; then
    echo "-> Packaging quantanexus-mgr..."
    cd quantanexus-mgr
    helm dependency update
    helm package .
    PACKAGED_FILE=$(ls *.tgz | head -1)
    if [ -n "$PACKAGED_FILE" ]; then
        mv "$PACKAGED_FILE" ../../"$CHART_DESTINATION"/
        echo "   Moved $PACKAGED_FILE to charts directory"
    fi
    cd ..
else
    echo "Warning: quantanexus-mgr directory not found"
fi

# 返回原始目录并清理临时目录
cd ..
echo "Cleaning up temporary directory..."
rm -rf "$QUANTANEXUS_TEMP_DIR"

# --- 从 CSV 文件下载依赖的 charts ---
echo "=== Downloading Dependency Charts from $CHART_FILE ==="

while IFS=, read -r NAME VERSION REPO
do
    # 跳过以 '#' 开头的注释行
    [[ "$NAME" =~ ^#.* ]] && continue

    # 移除行首尾的空格
    NAME=$(echo "$NAME" | xargs)
    VERSION=$(echo "$VERSION" | xargs)
    REPO=$(echo "$REPO" | xargs)

    if [ -z "$NAME" ] || [ -z "$VERSION" ] || [ -z "$REPO" ]; then
        continue
    fi

    echo "-> Pulling chart: $NAME (Version: $VERSION) from $REPO"
    helm pull "$NAME" --version "$VERSION" --repo "$REPO" --destination "$CHART_DESTINATION"/
done < "$CHART_FILE"

# --- 生成新的索引 ---
echo "Generating new repository index..."
helm repo index "$CHART_DESTINATION"/ --url https://helm.hi168.com/charts/

# --- 构建新镜像 ---
echo "Building new Docker image..."
docker build -t "$REGISTRY/$REPO_NAME:$TAG" .

# --- 推送镜像 ---
# echo "Pushing Docker image..."
docker push "$REGISTRY/$REPO_NAME:$TAG"

# --- 重启 deployment 以使用新镜像 ---
# echo "Restarting deployment..."
# kubectl rollout restart deployment/helm-quantanexus -n abc-platform

# --- 等待重启完成 ---
# echo "Waiting for rollout to complete..."
# kubectl rollout status deployment/helm-quantanexus -n abc-platform --timeout=180s

echo "=== Charts Update Complete ==="
