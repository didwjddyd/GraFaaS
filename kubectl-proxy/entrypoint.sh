#!/bin/bash

# DebugFS 마운트
mount_debugfs() {
    # /sys/kernel/debug 디렉토리가 존재하지 않는 경우
    if [ ! -d "/sys/kernel/debug" ]; then
        mkdir -p /sys/kernel/debug
    fi
    
    # DebugFS 마운트
    mount -t debugfs none /sys/kernel/debug
}

# TCPDump를 백그라운드에서 실행하는 함수
start_tcpdump() {
    # 포트 80의 패킷을 캡처합니다.
    tcpdump -i eth0 'tcp port 80' -w /tmp/tcpdump.pcap &
    TCPDUMP_PID=$!
    echo "Started tcpdump with PID: $TCPDUMP_PID"
}

# strace를 백그라운드에서 실행하는 함수
start_strace() {
    TARGET_PID=$1
    CONTAINER_NAME=$2

    # 컨테이너 이름에서 마지막 두 단어를 제거
    LOG_NAME=$(echo "$CONTAINER_NAME" | awk -F- '{OFS="-"; NF-=2; print}')

    strace -tt -q -f -e trace=execve,fork,clone,open,socket,bind,listen,accept4,connect,sendto,recvfrom,chmod,access,unlink,unlinkat,read,write -p $TARGET_PID -o /tmp/${LOG_NAME}_syscalls.log &
    STRACE_PID=$!
    echo "Started strace for $CONTAINER_NAME with PID: $STRACE_PID at PID: $TARGET_PID"
}

# DebugFS 마운트
mount_debugfs

# TCPDump 시작
start_tcpdump

# 컨테이너 정보 파일 읽기
while IFS=, read -r container_id container_name pid; do
    # 각 PID에 대해 strace 시작
    start_strace $pid $container_name
done < /tmp/container_info.txt

# 무한 루프를 돌며 프로세스 상태를 감시
while true; do
    if ! kill -0 $TCPDUMP_PID 2>/dev/null; then
        echo "tcpdump process has exited. Restarting..."
        start_tcpdump
    fi

    while IFS=, read -r container_id container_name pid; do
        STRACE_PID=$(pgrep -f "strace -tt -p $pid")
        if [ -z "$STRACE_PID" ]; then
            echo "strace for $container_name has exited. Restarting..."
            start_strace $pid $container_name
        fi
    done < /tmp/container_info.txt

    sleep 10
done

