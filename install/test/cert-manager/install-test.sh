#!/bin/bash

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true
  
#创建自签Issuer
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