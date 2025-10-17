# 1. 加仓库
helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
helm repo update

# 2. 安装（可改 storageClass / 节点亲和）
helm install sw seaweedfs/seaweedfs \
  --namespace seaweedfs --create-namespace \
  --set global.replicaCount=3 \
  --set filer.s3.enabled=true \
  --set filer.s3.port=8333

# 3. 查看 svc
kubectl -n seaweedfs get svc seaweedfs-filer-s3