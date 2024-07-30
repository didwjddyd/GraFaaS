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

# bpftrace를 백그라운드에서 실행하는 함수
start_bpftrace() {
    TARGET_PID=$1
    CONTAINER_NAME=$2

    # 컨테이너 이름에서 마지막 두 단어를 제거
    LOG_NAME=$(echo "$CONTAINER_NAME" | awk -F- '{OFS="-"; NF-=2; print}')

    bpftrace -e "
   kprobe:tcp_connect /pid==$TARGET_PID/ { 
   	printf(\"Connect\n\");
   }
   tracepoint:sock:inet_sock_set_state /pid==$TARGET_PID/ {
    // 상태 전환이 발생한 소켓 주소
    printf(\"PID: %d, Comm: %s\n\", pid, comm);
    printf(\"Socket addr: %llu\n\", args->skaddr);
    printf(\"Old state: %d, New state: %d\n\", args->oldstate, args->newstate);
    printf(\"Family: %d\n\", args->family);
    printf(\"Source port: %d, Destination port: %d\n\", args->sport, args->dport);
    printf(\"Timestamp: %d\n\", nsecs / 1000000);
} 

    // 시스템 호출 추적
    tracepoint:syscalls:sys_enter_* /pid == $TARGET_PID/ {
        printf(\"Syscall: %s, PID: %d\\n\", probe, pid);
    }

    // 네트워크 패킷 수신 추적
    tracepoint:net:netif_receive_skb /pid == $TARGET_PID/ {
        printf(\"Network packet received, PID: %d\\n\", pid);
    }
    " > /tmp/${LOG_NAME}_syscalls.log &
    BPTRACE_PID=$!
    echo "Started bpftrace for $CONTAINER_NAME with PID: $BPTRACE_PID at PID: $TARGET_PID"
}
# DebugFS 마운트
mount_debugfs

# TCPDump 시작
start_tcpdump

# 컨테이너 정보 파일 읽기
while IFS=, read -r container_id container_name pid; do
    # 각 PID에 대해 bpftrace 시작
    start_bpftrace $pid $container_name
done < /tmp/container_info.txt

# 무한 루프를 돌며 프로세스 상태를 감시
while true; do
    if ! kill -0 $TCPDUMP_PID 2>/dev/null; then
        echo "tcpdump process has exited. Restarting..."
        start_tcpdump
    fi

    while IFS=, read -r container_id container_name pid; do
        BPTRACE_PID=$(pgrep -f "bpftrace.*pid == $pid")
        if [ -z "$BPTRACE_PID" ]; then
            echo "bpftrace for $container_name has exited. Restarting..."
            start_bpftrace $pid $container_name
        fi
    done < /tmp/container_info.txt

    sleep 10
done


