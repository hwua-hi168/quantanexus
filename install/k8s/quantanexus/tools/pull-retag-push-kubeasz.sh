#!/usr/bin/env bash
# pull-retag-push.sh
# 拉取 values.yaml 中所有镜像并转存到 easzlab.io.local:5000

set -euo pipefail

NEW_REGISTRY="easzlab.io.local:5000"

# 定义要处理的完整镜像列表（不含 Redis）
images=(
  harbor.hi168.com/quantanexus/defaultbackend-amd64:1.5
  harbor.hi168.com/quantanexus/controller:v1.1.2
  swr.cn-north-4.myhuaweicloud.com/ddn-k8s/k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1
  harbor.hi168.com/quantanexus/postgresql:14.4.0-debian-11-r23
  harbor.hi168.com/quantanexus/postgres-exporter:0.10.1-debian-11-r24
  harbor.hi168.com/quantanexus/quantanexus-basic:0.1.5
  harbor.hi168.com/quantanexus/quantanexus-mgr:v1.0.2.0
  registry.cn-hangzhou.aliyuncs.com/hwua_namespace/nginx:reverse
  harbor.hi168.com/quantanexus/hi168-vue:v8.3.5.qn001v2
  harbor.hi168.com/quantanexus/abc-experiment-service:v1.3.2
  harbor.hi168.com/quantanexus/abc-webshell:v2.2.4.8
  harbor.hi168.com/quantanexus/abc-uploader:v1.0.0
  harbor.hi168.com/quantanexus/hwua-node-service:0.0.4
)

for img in "${images[@]}"; do
  echo "====== 处理 $img ======"
  # 生成新镜像名
  new_img="${NEW_REGISTRY}/${img#*/}"   # 去掉原域名/命名空间前缀，再加新域名

  # 拉取原镜像
  docker pull "$img"

  # 打新标签
  docker tag "$img" "$new_img"

  # 推到本地仓库
  docker push "$new_img"

  # 可选：删除本地旧镜像，节省空间
  # docker rmi "$img" "$new_img"
done

echo "全部完成！"