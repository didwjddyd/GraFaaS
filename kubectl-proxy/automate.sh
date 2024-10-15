#!/bin/bash

# Set variables
NAMESPACE="openfaas-fn"
IMAGE_NAME="jjhwan7099/grafaas:latest"

echo "NAME: CLUSTER-IP: PORT/PROTOCOL" > k8s_services_info
kubectl get svc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.clusterIP}: {range .spec.ports[*]}{.port}/{.protocol} {" "}{end}{"\n"}{end}' >> k8s_services_info

# Build the Docker image
docker build --network=host -t  $IMAGE_NAME . || { echo "Docker build failed"; exit 1; }

# Push the Docker image
docker push $IMAGE_NAME || { echo "Docker push failed"; exit 1; }

rm k8s_services_info

kubectl delete -f nginx-configmap.yaml -n openfaas
kubectl delete -f nginx-deployment.yaml -n openfaas
kubectl delete -f nginx-service.yaml -n openfaas
# Wait for a few seconds to ensure resources are deleted
sleep 1
CONTAINER_NAME="grafaas"
dots=1
# 컨테이너가 정상적으로 실행 중인지 확인
while true; do
    # 컨테이너 상태 확인
    CONTAINER_STATUS=$(docker ps -f "name=$CONTAINER_NAME" --format "{{.Status}}")

    if [[ "$CONTAINER_STATUS" != *"Up"* ]]; then
	printf "\n"
        printf "$CONTAINER_NAME 컨테이너가 정상적으로 삭제되었습니다.\n"
        break
    else
        # 대기 중 메시지 출력
        case $dots in
            1) printf "\r$CONTAINER_NAME 컨테이너가 아직 삭제되지 않았습니다. 대기 중.  " ;;
            2) printf "\r$CONTAINER_NAME 컨테이너가 아직 삭제되지 않았습니다. 대기 중.. " ;;
            3) printf "\r$CONTAINER_NAME 컨테이너가 아직 삭제되지 않았습니다. 대기 중... " ;;
        esac

        # dots 값 순환
        dots=$(( (dots % 3) + 1 ))
        sleep 0.5  # 0.5초 대기 후 다시 확인
    fi
done

./delete_func.sh
sleep 1

# 점 순환을 위한 dots 변수 초기화
dots=1

# openfaas-fn 네임스페이스의 Pod 상태 확인
while true; do
    # Pod 목록 가져오기
    pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null)

    # Pod가 존재하는지 확인
    if [ -z "$pods" ]; then
	printf "\n"
        printf "openfaas-fn 네임스페이스에 Pod가 없습니다. 다음 명령어로 넘어갑니다.\n"
        break
    else
        # Pod가 존재하는 동안 대기 중 메시지 출력
        case $dots in
            1) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재합니다. 대기 중.  " ;;
            2) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재합니다. 대기 중.. " ;;
            3) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재합니다. 대기 중... " ;;
        esac

        # dots 값 순환
        dots=$(( (dots % 3) + 1 ))
        sleep 0.5  # 5초 대기 후 다시 확인
    fi
done

# Kubernetes service start
kubectl apply -f nginx-configmap.yaml -n openfaas || { echo "Failed to apply nginx-configmap"; exit 1; }
kubectl apply -f nginx-deployment.yaml -n openfaas || { echo "Failed to apply nginx-deployment"; exit 1; }
kubectl apply -f nginx-service.yaml -n openfaas || { echo "Failed to apply nginx-service"; exit 1; }

CONTAINER_NAME="grafaas"
dots=1
# 컨테이너가 정상적으로 실행 중인지 확인
while true; do
    # 컨테이너 상태 확인
    CONTAINER_STATUS=$(docker ps -f "name=$CONTAINER_NAME" --format "{{.Status}}")

    if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
	printf "\n"
        printf "$CONTAINER_NAME 컨테이너가 정상적으로 실행되었습니다.\n"
        break
    else
        # 대기 중 메시지 출력
        case $dots in
            1) printf "\r$CONTAINER_NAME 컨테이너가 아직 실행되지 않았습니다. 대기 중.  " ;;
            2) printf "\r$CONTAINER_NAME 컨테이너가 아직 실행되지 않았습니다. 대기 중.. " ;;
            3) printf "\r$CONTAINER_NAME 컨테이너가 아직 실행되지 않았습니다. 대기 중... " ;;
        esac

        # dots 값 순환
        dots=$(( (dots % 3) + 1 ))
        sleep 0.5  # 0.5초 대기 후 다시 확인
    fi
done

faas-cli up -f hello-retail.yaml

echo "All steps completed successfully."

