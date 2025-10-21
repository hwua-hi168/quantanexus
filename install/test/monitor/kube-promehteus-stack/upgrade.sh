#!/bin/bash 


helm upgrade prometheus prometheus-community/kube-prometheus-stack --namespace prom -f values.yaml
