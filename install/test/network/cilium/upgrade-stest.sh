
  helm upgrade cilium ./cilium -n kube-system --reuse-values \
  --set bandwidthManager.bbr=true \
  --set devices=hi168-business \
  --set debug.enabled=true \
  --set debug.verbose=datapath \
  --set bgpControlPlane.enabled=true \
  --set bpf.lbExternalClusterIP=true  \
  --set bpf.masquerade=false \
  --set loadBalancer.acceleration=native \
  --set loadBalancer.mode=hybrid \
  --set routingMode=native

  #--set ingressController.enabled=true \
    #--set ingressController.loadbalancerMode=dedicated \
  #--set loadBalancer.mode=dsr
  #--set loadBalancer.mode=dsr
  #--set loadBalancer.dsrDispatch=opt \
  #--set routingMode=native \
  #--set routingMode=tunnel


  #--set tunnel=enabled \
~