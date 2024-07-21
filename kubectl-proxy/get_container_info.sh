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
