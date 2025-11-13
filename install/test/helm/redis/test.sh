# 获取密码
export REDIS_PASSWORD=$(kubectl get secret -n redis ${RELEASE} -o jsonpath="{.data.redis-password}" | base64 -d)

# 连 Sentinel 看主节点
kubectl run redis-cli -it --rm --restart=Never \
  --image docker.io/bitnami/redis:7.0.12-debian-11-r2 -- \
  redis-cli -h ${RELEASE}-sentinel -p 26379 -a $REDIS_PASSWORD sentinel get-master-addr-by-name mymaster

# 连主节点写数据
kubectl run redis-cli-master -it --rm --restart=Never \
  --image docker.io/bitnami/redis:7.0.12-debian-11-r2 -- \
  redis-cli -h ${RELEASE}-master -p 6379 -a $REDIS_PASSWORD set foo bar