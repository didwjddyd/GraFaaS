#!/bin/bash

# OpenFaaS Gateway의 PID 찾기
GATEWAY_PID=$(ps aux | grep './gateway' | grep -v grep | awk '{print $2}')

# PID가 존재하는지 확인
if [ -z "$GATEWAY_PID" ]; then
    echo "OpenFaaS Gateway PID를 찾을 수 없습니다."
    exit 1
fi

echo "Found OpenFaaS Gateway PID: $GATEWAY_PID"

# nsenter를 통해 tcpdump 실행
nsenter --target "$GATEWAY_PID" tcpdump -i any -s 0 -A 'tcp port 8080' | while read line; do
    # 'In'으로 시작하는 로그 필터링
    if echo "$line" | grep -qi 'In '; then
        # 헬스 체크 요청 제외
        if ! echo "$line" | grep -qi '/health'; then
            # POST 요청인지 확인
            if echo "$line" | grep -qi 'POST /function'; then
                if ! echo "$line" | grep -qi 'openfaas-fn'; then
                    # 함수 이름 추출
                    function_name=$(echo "$line" | grep -oP '(?<=POST /function/)[^ ]+')
                    if [ -n "$function_name" ]; then
                        #함수 호출 사이클에서 가장 먼저 호출된 함수 표시 *user의 진입을 확인하기 위함*
                        echo "$function_name" > /tmp/func_call_src_info
                    fi
                fi
            fi
        fi
    fi
done
