#!/bin/bash

# Set variables
NAMESPACE="openfaas-fn"
IMAGE_NAME="jjhwan7099/tcpdump_grafaas:latest"
CONTAINER_INFO_FILE="container_info.txt"

# Make the script executable
chmod +x get_container_info.sh

# Run the get_container_info.sh script
./get_container_info.sh || { echo "Failed to collect container information"; exit 1; }

# Build the Docker image
docker build -t $IMAGE_NAME . || { echo "Docker build failed"; exit 1; }

# Push the Docker image
docker push $IMAGE_NAME || { echo "Docker push failed"; exit 1; }

# Clean up: remove get_container_info.sh and container_info.txt
#rm get_container_info.sh
rm $CONTAINER_INFO_FILE

# Function to delete Kubernetes resources if they exist
delete_if_exists() {
    local resource_type=$1
    local resource_name=$2

    if kubectl get "$resource_type" "$resource_name" -n $NAMESPACE &>/dev/null; then
        echo "Deleting $resource_type $resource_name..."
        kubectl delete "$resource_type" "$resource_name" -n $NAMESPACE || { echo "Failed to delete $resource_type $resource_name"; }
    else
        echo "$resource_type $resource_name does not exist, skipping deletion."
    fi
}

# Delete Kubernetes resources
delete_if_exists configmap nginx-configmap
delete_if_exists deployment nginx-deployment
delete_if_exists service nginx-service

# Wait for a few seconds to ensure resources are deleted
sleep 10

# Kubernetes service start
kubectl apply -f nginx-configmap.yaml -n openfaas || { echo "Failed to apply nginx-configmap"; exit 1; }
kubectl apply -f nginx-deployment.yaml -n openfaas || { echo "Failed to apply nginx-deployment"; exit 1; }
kubectl apply -f nginx-service.yaml -n openfaas || { echo "Failed to apply nginx-service"; exit 1; }

echo "All steps completed successfully."


