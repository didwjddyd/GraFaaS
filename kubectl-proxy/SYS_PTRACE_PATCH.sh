#!/bin/bash

# 네임스페이스 설정
NAMESPACE="openfaas-fn"

# 패치할 함수 목록
FUNCTIONS=(
  "product-purchase-authorize-cc"
  "product-purchase"
  "product-purchase-get-price"
  "product-purchase-publish"
)

# SYS_PTRACE 권한을 추가하는 패치
for FUNCTION in "${FUNCTIONS[@]}"
do
  echo "Patching $FUNCTION..."

  kubectl patch deployment "$FUNCTION" -n "$NAMESPACE" --patch '{
    "spec": {
      "template": {
        "spec": {
          "containers": [
            {
              "name": "'"$FUNCTION"'",
              "securityContext": {
                "capabilities": {
                  "add": ["SYS_PTRACE"]
                }
              }
            }
          ]
        }
      }
    }
  }'

  if [ $? -eq 0 ]; then
    echo "Successfully patched $FUNCTION"
  else
    echo "Failed to patch $FUNCTION"
  fi
done

