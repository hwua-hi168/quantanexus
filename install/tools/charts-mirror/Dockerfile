FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/library/nginx:1.24.0-alpine

# 创建 Helm 仓库目录
RUN mkdir -p /usr/share/nginx/html/charts

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

# 复制 charts 文件
COPY charts/ /usr/share/nginx/html/charts/

# 设置权限
RUN chown -R nginx:nginx /usr/share/nginx/html/charts && \
    chmod -R 755 /usr/share/nginx/html && \
    # 验证文件完整性
    ls -la /usr/share/nginx/html/charts/ && \
    echo "Charts in image:" && \
    find /usr/share/nginx/html/charts/ -name "*.tgz" -o -name "*.yaml"

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]