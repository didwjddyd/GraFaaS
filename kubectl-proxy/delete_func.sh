#!/bin/bash

# 모든 함수 목록 가져오기
functions=$(faas-cli list --quiet)

# 각 함수를 삭제
for function in $functions; do
    echo "Deleting function: $function"
    faas-cli remove $function
done

echo "All functions deleted."

