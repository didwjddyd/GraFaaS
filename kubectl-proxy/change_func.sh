#!/bin/bash

# 모든 함수 이름을 가져옵니다.
FUNCTIONS=$(faas-cli list --namespace openfaas-fn | awk 'NR>1 {print $1}')

# 모든 함수에 대해 반복합니다.
for FUNCTION_NAME in $FUNCTIONS; do
    echo "현재 배포 정보 가져오는 중: $FUNCTION_NAME"
    
    # 현재 배포 정보를 가져옵니다.
    CURRENT_DEPLOYMENT=$(faas-cli describe $FUNCTION_NAME --namespace openfaas-fn)

    # 배포 정보를 yaml 파일로 출력합니다.
    echo "$CURRENT_DEPLOYMENT" > current_deployment.yml

    # 호스트 PID를 true로 설정
    echo "hostPID: true 추가 중..."
    # sed를 사용하여 hostPID를 추가합니다.
    sed -i '' '/^spec:/a\
  hostPID: true
' current_deployment.yml

    # provider 정보를 추가
    echo "provider:\
  name: openfaas\
  gateway: http://<gateway-url>" > temp_provider.yml

    # provider 정보를 현재 배포 yaml 파일에 추가
    cat temp_provider.yml current_deployment.yml > final_deployment.yml

    # 업데이트된 yaml 파일로 함수를 재배포합니다.
    echo "함수 재배포 중: $FUNCTION_NAME"
    faas-cli deploy -f final_deployment.yml --namespace openfaas-fn

    # 임시 파일 제거
    rm current_deployment.yml temp_provider.yml final_deployment.yml

    echo "재배포 완료: $FUNCTION_NAME에 hostPID: true 적용되었습니다."
done

echo "모든 함수에 대해 hostPID: true가 적용되었습니다."

