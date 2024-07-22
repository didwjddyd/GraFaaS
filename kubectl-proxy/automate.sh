#!/bin/bash

# Set variables
NAMESPACE="openfaas-fn"
IMAGE_NAME="jjhwan7099/tcpdump_grafaas:latest"
CONTAINER_INFO_FILE="container_info.txt"

cat << 'EOF' > get_container_info.sh
#!/bin/bash

NAMESPACE="openfaas-fn"
CONTAINER_INFO_FILE="container_info.txt"

# 기존 파일 삭제
if [ -f $CONTAINER_INFO_FILE ]; then
    rm $CONTAINER_INFO_FILE
fi

# 모든 포드 가져오기
PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

for POD in $PODS; do
  # 각 포드의 컨테이너 ID 가져오기
  CONTAINER_IDS=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[*].containerID}' | sed 's/docker:\/\/\([a-z0-9]\{12\}\).*/\1/')
  for CONTAINER_ID in $CONTAINER_IDS; do
    # 컨테이너 PID 가져오기
    PID=$(docker inspect --format '{{.State.Pid}}' $CONTAINER_ID)
    echo "$CONTAINER_ID,$POD,$PID" >> $CONTAINER_INFO_FILE
  done
done

echo "Container information has been saved to $CONTAINER_INFO_FILE"

EOF

# Make the script executable
chmod +x get_container_info.sh

# Run the get_container_info.sh script
./get_container_info.sh || { echo "Failed to collect container information"; exit 1; }

# Build the Docker image
docker build -t $IMAGE_NAME . || { echo "Docker build failed"; exit 1; }

# Push the Docker image
docker push $IMAGE_NAME || { echo "Docker push failed"; exit 1; }

# Clean up: remove get_container_info.sh and container_info.txt
rm get_container_info.sh
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


