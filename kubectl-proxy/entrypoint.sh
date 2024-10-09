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

    strace -ttt -q -o /tmp/${LOG_NAME}_syscalls.log -e trace=execve,fork,clone,open,socket,bind,listen,accept4,connect,sendto,recvfrom,chmod,chown,access,unlink,unlinkat -ff -p $TARGET_PID &
    STRACE_PID=$!
    echo "Started strace for $CONTAINER_NAME with PID: $STRACE_PID at PID: $TARGET_PID"
}

# 프로세스 상태를 감시하는 함수
monitor_processes() {
    # index.js 프로세스의 PID 목록 추출
    pids=$(ps aux | grep index.js | grep -v grep | awk '{print $2}')

    # PID가 없으면 종료
    if [ -z "$pids" ]; then
        echo "index.js 프로세스를 찾을 수 없습니다."
        exit 1
    fi

    for pid in $pids; do
        # HOSTNAME 환경 변수 추출
        func_name=$(cat /proc/$pid/environ | tr '\0' '\n' | grep '^HOSTNAME=' | cut -d '=' -f 2)

        # func_name이 없으면 무시하고 다음 PID로 이동
        if [ -z "$func_name" ]; then
            echo "PID $pid에서 HOSTNAME을 찾을 수 없습니다."
            continue
        fi

        # strace PID 확인
        STRACE_PID=$(pgrep -f "strace -ttt -p $pid")
        if [ -z "$STRACE_PID" ]; then
            echo "strace for $func_name has exited. Restarting..."
            # /tmp/<func_name> 디렉토리 생성, 이미 존재하는 경우는 무시
            mkdir -p /tmp/"$func_name"
            # strace 실행
            start_strace $pid "$func_name"
        fi
    done
}

# DebugFS 마운트
mount_debugfs

# TCPDump 시작
start_tcpdump

#프로세스 감시 함수 호출
monitor_processes

# 무한 루프를 돌며 프로세스 상태를 감시
while true; do
    if ! kill -0 $TCPDUMP_PID 2>/dev/null; then
        echo "tcpdump process has exited. Restarting..."
        start_tcpdump
    fi
    sleep 10
done

