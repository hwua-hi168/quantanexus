helm repo add hi168 https://helm.hi168.com/charts 2>/dev/null
helm repo update hi168

helm upgrade --install juicefs-csi-driver hi168/juicefs-csi-driver \
    -n juicefs \
    --create-namespace -f values-csi-driver.yaml.yaml

helm upgrade --install  juicefs-s3-gateway hi168/juicefs-s3-gateway \
    -n juicefs --create-namespace \
    -f values-s3-gateway.yaml