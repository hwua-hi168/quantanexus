# Dockerfile for building images to run kubeasz in a container
# @author:  gjmzj
# @repo:     https://github.com/hwua-hi168/quantanexus

FROM easzlab/ansible:2.14.4-lite

# Var will be set by build-args
ARG QUANTANEXUS_INSATLLER_VER=

ENV TZ="Asia/Shanghai"

RUN set -x \
    # Downloading quantanexus_install's code 
    && wget https://github.com/hwua-hi168/quantanexus/archive/refs/tags/"$QUANTANEXUS_INSATLLER_VER".tar.gz \
    && tar zxf ./"$QUANTANEXUS_INSATLLER_VER".tar.gz \
    && mv kubeasz-"$QUANTANEXUS_INSATLLER_VER" /etc/kubeasz \
    && ln -s -f /etc/kubeasz/ezctl /usr/bin/ezctl \
    && ln -s -f /etc/kubeasz/ezdown /usr/bin/ezdown \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python \
    && ln -s -f /usr/local/bin/python3.11 /usr/bin/python3 \
    && mkdir -p /usr/libexec \
    && ln -s /usr/bin/python3 /usr/libexec/platform-python \
    # Cleaning
    && rm -rf ./"$QUANTANEXUS_INSATLLER_VER".tar.gz