#!/bin/bash
# 原仓库，测试原因加入了hi168仓库
# helm repo add jetstack https://charts.jetstack.io
helm repo add hi168 https://hi168.com/charts 
helm repo update
helm upgrade --install cert-manager hi68/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true
  
#创建自签Issuer ? 这个应该放在quantanexus里吧？ 

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
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
spec:
  ca:
    secretName: root-ca-secret
EOF