#!/bin/bash

helm repo add harbor https://helm.goharbor.io

helm upgrade --install harbor harbor/harbor -n harbor --create-namespace \
  --set expose.type=nodePort \
  --set externalURL=http://192.168.103.161:30002 \
  --set expose.tls.enabled=false \
  --set expose.nodePort.ports.http.port=80 \
  --set expose.nodePort.ports.http.nodePort=32600 \
  --set expose.nodePort.ports.https.port=443 \
  --set expose.nodePort.ports.https.nodePort=30003 \
  --set persistence.enabled=true \
  --set persistence.persistentVolumeClaim.registry.storageClass=longhorn \
  --set persistence.persistentVolumeClaim.registry.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.registry.size=15Gi \
  --set persistence.persistentVolumeClaim.jobservice.storageClass=longhorn \
  --set persistence.persistentVolumeClaim.jobservice.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.jobservice.size=10Gi \
  --set persistence.persistentVolumeClaim.database.storageClass=longhorn \
  --set persistence.persistentVolumeClaim.database.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.database.size=10Gi \
  --set persistence.persistentVolumeClaim.redis.storageClass=longhorn \
  --set persistence.persistentVolumeClaim.redis.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.redis.size=5Gi \
  --set database.internal.initContainer.permissions.enabled=true \
  --set harborAdminPassword=admin