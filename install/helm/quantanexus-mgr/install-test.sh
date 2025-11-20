
#!/bin/bash

helm repo add hi168 https://helm.hi168.com/charts/ 2>/dev/null
helm repo update  hi168    

helm install quantanexus hi168/quantanexus-mgr --version 1.0.0 \
  --namespace quantanexus --create-namespace \
  --set global.domainName=qntest002.hi168.com \
  --set global.masterNode=master1 \
  --set "global.masterNodes=master1\,master2" \
  --set global.workerNodes=worker1    -f values.yaml
  