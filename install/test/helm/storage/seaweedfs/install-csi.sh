#!/bin/bash

helm upgrade --install seaweedfs-csi-driver seaweedfs-csi-driver/seaweedfs-csi-driver -n seaweedfs --create-namespace -f install-csi.yaml