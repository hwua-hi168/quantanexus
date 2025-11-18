helm repo add juicefs https://juicedata.github.io/charts
helm repo update

helm upgrade --install juicefs-csi-driver juicefs/juicefs-csi-driver \
    -n juicefs \
    --create-namespace -f values.yaml

helm upgrade --install  s3-gateway juicefs/juicefs-s3-gateway \
    -n juicefs --create-namespace \
    -f values-s3-gateway.yaml