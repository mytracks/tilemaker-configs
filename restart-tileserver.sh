#!/bin/sh

export KUBECONFIG=/home/gis/.kube/config

kubectl rollout restart deployment tileserver-gl -n tileserver-gl
