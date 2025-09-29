#!/usr/bin/env bash
# pull-retag-push-aliyun.sh
# 拉取 values.yaml 中所有镜像并转存到 registry.cn-hangzhou.aliyuncs.com

set -euo pipefail

NEW_REGISTRY="registry.cn-hangzhou.aliyuncs.com"

# 定义要处理的完整镜像列表
images=(
  # Ingress Nginx 相关镜像
  "harbor.hi168.com/quantanexus/defaultbackend-amd64:1.5"
  "harbor.hi168.com/quantanexus/controller:v1.1.2"
  # "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1"
  
  # PostgreSQL 相关镜像
  "harbor.hi168.com/quantanexus/postgresql:14.4.0-debian-11-r23"
  "harbor.hi168.com/quantanexus/postgres-exporter:0.10.1-debian-11-r24"
  
  # Quantanexus 核心组件
  "harbor.hi168.com/quantanexus/quantanexus-basic:1.0.5"
  "harbor.hi168.com/quantanexus/quantanexus-mgr:v8.3.7.5"
  "harbor.hi168.com/quantanexus/nginx:reverse"
  "harbor.hi168.com/quantanexus/hi168-vue:v8.3.7.qn5"

  # ABC 实验服务
  "harbor.hi168.com/quantanexus/abc-experiment-service:v1.3.2"
  
  # ABC WebShell
  "harbor.hi168.com/quantanexus/abc-webshell:v2.2.4.8"
  
  # ABC Uploader
  "harbor.hi168.com/quantanexus/abc-uploader:v1.0.0"
  
  # HWUA Node Service
  "harbor.hi168.com/quantanexus/hwua-node-service:0.0.4"
  
  # Redis (虽然你提到不含 Redis，但 values.yaml 中有配置)
  "harbor.hi168.com/quantanexus/redis:7.2.4"
)
# docker tag   "harbor.hi168.com/abc/quantanexus-basic:1.0.5"   "harbor.hi168.com/quantanexus/quantanexus-basic:1.0.5"  
# docker tag   "harbor.hi168.com/abc/quantanexus-mgr:v8.3.7.5"  "harbor.hi168.com/quantanexus/quantanexus-mgr:v8.3.7.5"
# docker tag   "harbor.hi168.com/abc/hi168-vue:v8.3.7.qn5"  "harbor.hi168.com/quantanexus/hi168-vue:v8.3.7.qn5"


for img in "${images[@]}"; do
  echo "====== 处理 $img ======"
  
  # 生成新镜像名 - 移除原 registry 部分，保留命名空间和镜像名
  if [[ $img == harbor.hi168.com/* ]]; then
    new_img="${NEW_REGISTRY}/${img#harbor.hi168.com/}"
  elif [[ $img == swr.cn-north-4.myhuaweicloud.com/* ]]; then
    # 特殊处理华为云镜像
    new_img="${NEW_REGISTRY}/ddn-k8s/${img#swr.cn-north-4.myhuaweicloud.com/ddn-k8s/}"
  else
    # 对于没有域名的镜像（如 abc/quantanexus-basic），直接添加新域名
    new_img="${NEW_REGISTRY}/${img}"
  fi

  echo "原镜像: $img"
  echo "新镜像: $new_img"

  # 拉取原镜像
  docker pull "$img"

  # 打新标签
  docker tag "$img" "$new_img"

  # 推到新仓库
  docker push "$new_img"

  echo "完成: $img -> $new_img"
  echo ""
done

echo "全部镜像处理完成！"