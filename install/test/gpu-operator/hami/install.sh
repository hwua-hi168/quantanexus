#!/bin/bash

#kubectl label nodes {nodeid} gpu=on
helm repo add hami-charts https://project-hami.github.io/HAMi/
helm install hami hami-charts/hami -n kube-system


helm repo add hami-webui https://project-hami.github.io/HAMi-WebUI
helm install hami-webui hami-webui/hami-webui --set externalPrometheus.enabled=true --set externalPrometheus.address="http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090" -n kube-system
