#!/bin/bash 
#helm repo add volcano-sh https://volcano-sh.github.io/helm-charts
helm repo add hi168 https://hi168.com/charts 
helm upgrade --install volcano hi168/volcano -n volcano-system --create-namespace
