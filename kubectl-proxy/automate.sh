#!/bin/bash

# Set variables
NAMESPACE="openfaas-fn"
IMAGE_NAME="jjhwan7099/grafaas:latest"

for ((i=1; i<=200; i++)); do
    echo "Iteration $i of 200"

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

    # openfaas-fn 네임스페이스의 Pod 상태 확인
    while true; do
        # Pod 목록 가져오기
        pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null)

        # Pod가 존재하는지 확인
        if [ ! -z "$pods" ]; then
        printf "\n"
            printf "openfaas-fn 네임스페이스에 Pod이 정상적으로 실행되었습니다. 다음 명령어로 넘어갑니다.\n"
            break
        else
            # Pod가 존재하는 동안 대기 중 메시지 출력
            case $dots in
                1) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재하지 않습니다. 대기 중.  " ;;
                2) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재하지 않습니다. 대기 중.. " ;;
                3) printf "\ropenfaas-fn 네임스페이스에 Pod가 존재하지 않습니다. 대기 중... " ;;
            esac

            # dots 값 순환
            dots=$(( (dots % 3) + 1 ))
            sleep 0.5  # 5초 대기 후 다시 확인
        fi
    done

    # grafaas 컨테이너 이름 자동으로 가져오기
    GRAFAAS_CONTAINER=$(kubectl get pods -n openfaas --no-headers | grep 'grafaas' | awk '{print $1}')

    # 함수 이름 리스트를 가져오기
    function_list=$(kubectl exec -n openfaas "$GRAFAAS_CONTAINER" -- cat /tmp/function_list)

    # pods 배열 만들기
    pods=($(kubectl get pods -n openfaas-fn --no-headers | awk '{print $1}' | sed 's/-[^-]*-[^-]*$//'))

    # 모든 pod 이름이 function_list에 존재하는지 확인
    while true; do
        # function_list 파일 존재 여부 확인
        if kubectl exec -n openfaas "$GRAFAAS_CONTAINER" -- test -f /tmp/function_list; then
            function_list=$(kubectl exec -n openfaas "$GRAFAAS_CONTAINER" -- cat /tmp/function_list)
            
            all_exist=true
            for pod in "${pods[@]}"; do
                if ! echo "$function_list" | grep -q "$pod"; then
                    all_exist=false
                    break
                fi
            done

            # 모두 존재하면 루프 탈출
            if $all_exist; then
                break
            fi
        else
            echo "/tmp/function_list 파일이 아직 존재하지 않습니다. 잠시 후 다시 확인합니다."
        fi

        # 잠시 대기 후 다시 확인
        sleep 2
    done

    curl -X POST http://localhost:80/function/product-purchase \
        -H "Content-Type: application/json" \
        -d '{
            "id": "test",
            "user": "testuser",
            "creditCard": "0000-0000-0000-0000"
        }'

    sleep 1.5


    FILE_PATH="/system_call_graph.png"
    GRAPHS_DIR="$HOME/Documents/graphs"
    GRAPHS_DOT_DIR="$HOME/Documents/graphs_dot"

    # 디렉토리 생성
    mkdir -p "$GRAPHS_DIR" "$GRAPHS_DOT_DIR"

    # 파일이 존재할 때까지 대기
    while true; do
        if kubectl exec -n openfaas "$GRAFAAS_CONTAINER" -- test -f "$FILE_PATH"; then
            echo "File exists. Copying to local..."

            # graphs 폴더에 저장할 파일명 생성
            GRAPH_COUNT=$(ls "$GRAPHS_DIR" | wc -l)
            GRAPH_FILE="$GRAPHS_DIR/system_call_graph_$((GRAPH_COUNT + 1)).png"
            
            # graphs_dot 폴더에 저장할 파일명 생성
            GRAPH_DOT_COUNT=$(ls "$GRAPHS_DOT_DIR" | wc -l)
            GRAPH_DOT_FILE="$GRAPHS_DOT_DIR/system_call_graph_$((GRAPH_DOT_COUNT + 1)).dot"

            # 파일 복사
            kubectl cp openfaas/$GRAFAAS_CONTAINER:$FILE_PATH $GRAPH_FILE
            echo "File copied to $GRAPH_FILE"

            # 같은 파일을 graphs_dot에도 복사
            kubectl cp openfaas/$GRAFAAS_CONTAINER:/system_call_graph $GRAPH_DOT_FILE
            echo "File copied to $GRAPH_DOT_FILE"

            break
        else
            echo "File does not exist yet. Waiting..."
            sleep 5  # 5초 대기 후 다시 확인
        fi
    done
done

