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
}

# bpftrace를 백그라운드에서 실행하는 함수
start_bpftrace() {
    TARGET_PID=$1

    bpftrace -e "
    tracepoint:syscalls:sys_enter_* /pid == $TARGET_PID/ {
        printf(\"Syscall: %s, PID: %d\\n\", probe, pid);
    }
    tracepoint:net:netif_receive_skb /pid == $TARGET_PID/ {
        // skb의 필드를 확인하여 출력합니다.
        // 필드 이름을 확인한 후 주석을 제거하고 사용하세요.
        // 예: printf(\"Network packet received, PID: %d, Length: %d\\n\", pid, args->skb->len);
        printf(\"Network packet received, PID: %d\\n\", pid);
    }
    " > /tmp/syscalls.log &
    BPTRACE_PID=$!
}

# PID 설정
TARGET_PID=98459  # 테스트할 PID

# DebugFS 마운트
mount_debugfs

# TCPDump와 bpftrace 시작
start_tcpdump
start_bpftrace $TARGET_PID

# 무한 루프를 돌며 tcpdump의 출력 감시
while true; do
    # 컨테이너가 종료되지 않도록 무한 대기
    wait $TCPDUMP_PID
done
