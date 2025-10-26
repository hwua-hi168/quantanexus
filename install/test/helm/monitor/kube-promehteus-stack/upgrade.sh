#!/bin/bash 


helm upgrafde --install prometheus hi168/kube-prometheus-stack --namespace prom  -f values.yaml
