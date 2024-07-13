#!/bin/bash

# TCPDump를 백그라운드에서 실행하는 함수
start_tcpdump() {
    tcpdump -i eth0 -w /tmp/tcpdump.pcap &
    TCPDUMP_PID=$!
}

# TCPDump 시작
start_tcpdump

# 컨테이너가 종료되지 않도록 무한 대기
wait $TCPDUMP_PID

