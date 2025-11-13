# Dockerfile for building images to run kubeasz in a container
# @author:  gjmzj
# @repo:     https://github.com/hwua-hi168/quantanexus

FROM easzlab/ansible:2.14.4-lite

# Var will be set by build-args
ARG QNI_VER=

ENV TZ="Asia/Shanghai"
COPY install/test/kubeasz /etc/kubeasz
RUN set -x \
    && ln -s -f /etc/kubeasz/ezctl /usr/bin/ezctl \
    && ln -s -f /etc/kubeasz/ezdown /usr/bin/ezdown \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python3 \
    && pip install --upgrade pip \
    && pip3 install kubernetes \
    && mkdir -p /usr/libexec \
    && ln -s /usr/bin/python3 /usr/libexec/platform-python 