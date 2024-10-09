#!/bin/bash

# Set variables
NAMESPACE="openfaas-fn"
IMAGE_NAME="jjhwan7099/tcpdump_grafaas:latest"

# Build the Docker image
docker build --network=host -t  $IMAGE_NAME . || { echo "Docker build failed"; exit 1; }

# Push the Docker image
docker push $IMAGE_NAME || { echo "Docker push failed"; exit 1; }

kubectl delete -f nginx-configmap.yaml -n openfaas
kubectl delete -f nginx-deployment.yaml -n openfaas
kubectl delete -f nginx-service.yaml -n openfaas
# Wait for a few seconds to ensure resources are deleted
sleep 1

# Kubernetes service start
kubectl apply -f nginx-configmap.yaml -n openfaas || { echo "Failed to apply nginx-configmap"; exit 1; }
kubectl apply -f nginx-deployment.yaml -n openfaas || { echo "Failed to apply nginx-deployment"; exit 1; }
kubectl apply -f nginx-service.yaml -n openfaas || { echo "Failed to apply nginx-service"; exit 1; }

echo "All steps completed successfully."


