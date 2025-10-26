#!/bin/bash
# 原仓库，测试原因使用了hi168镜像仓库
# helm repo add jetstack https://charts.jetstack.io
helm repo add hi168 https://hi168.com/charts 
helm repo update
helm upgrade --install cert-manager hi68/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true -f values-cert-manager.yaml

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca-issuer
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: quantanexus-cs
    meta.helm.sh/release-namespace: quantanexus-cs
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: quantanexus-cs
    meta.helm.sh/release-namespace: quantanexus-cs
spec:
  secretName: root-ca-secret
  commonName: "QuantaNexus Root CA"
  subject:
    organizations:
      - "QuantaNexus"
  duration: 87600h
  renewBefore: 720h
  issuerRef:
    name: root-ca-issuer
    kind: ClusterIssuer
  isCA: true
  usages:
    - digital signature
    - key encipherment
    - cert sign
    - crl sign
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: quantanexus-ca-issuer
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: quantanexus-cs
    meta.helm.sh/release-namespace: quantanexus-cs
spec:
  ca:
    secretName: root-ca-secret
EOF  