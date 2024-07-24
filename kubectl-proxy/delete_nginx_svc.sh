#!/bin/bash

kubectl delete -f nginx-configmap.yaml -n openfaas
kubectl delete -f nginx-deployment.yaml -n openfaas
kubectl delete -f nginx-service.yaml -n openfaas
