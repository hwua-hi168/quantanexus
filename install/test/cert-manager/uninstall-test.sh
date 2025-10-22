
kubectl delete ClusterIssuer selfsigned-issuer -n cert-manager 
helm uninstall cert-manager -n cert-manager 