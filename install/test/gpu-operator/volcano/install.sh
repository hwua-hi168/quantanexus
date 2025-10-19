#!/bin/bash 
helm repo add volcano-sh https://volcano-sh.github.io/helm-charts
helm upgrade --install volcano volcano-sh/volcano -n volcano-system --create-namespace
