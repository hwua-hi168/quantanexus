# Dockerfile for building images to run kubeasz in a container
# @author:  gjmzj
# @repo:     https://github.com/hwua-hi168/quantanexus

FROM easzlab/ansible:2.14.4-lite

# Var will be set by build-args
ARG QNI_VER=
ARG KUBECTL_VERSION=v1.34.2 
ENV TZ="Asia/Shanghai"
COPY install/test/kubeasz /etc/qubeasz
RUN set -x \
    && apk update && apk add --no-cache curl tar openssl ssh  \
    && curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && helm version --short \
    && KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -fsSL -o /usr/bin/kubectl "${KUBECTL_URL}" \
    && chmod +x /usr/bin/kubectl \
    && kubectl version --client  \
    && rm -rf /get_helm.sh /var/cache/apk/* \
    && ln -s -f /etc/kubeasz/ezctl /usr/bin/ezctl \
    && ln -s -f /etc/kubeasz/ezdown /usr/bin/ezdown \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python3 \
    && pip install --upgrade pip \
    && pip3 install kubernetes \
    && ansible-galaxy collection install kubernetes.core \
    && mkdir -p /usr/libexec \
    && ln -s /usr/bin/python3 /usr/libexec/platform-python 