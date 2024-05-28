#!/bin/bash

# TCPDump를 백그라운드에서 실행하는 함수
start_tcpdump() {
    tcpdump -i eth0 -w /tmp/tcpdump.pcap &
    TCPDUMP_PID=$!
}

# TCPDump 시작
start_tcpdump

# tcpdump.pcap 파일이 생성될 때까지 기다림
while [ ! -f /tmp/tcpdump.pcap ]; do
    sleep 1
done

# tcpdump 파일이 업데이트될 때마다 스크립트 실행
while inotifywait -e modify /tmp/tcpdump.pcap; do
    # 파일이 비어 있지 않은지 확인
    if [ -s /tmp/tcpdump.pcap ]; then
        python3 /tmp/pcap_summary.py

        # tcpdump 프로세스 종료
        kill $TCPDUMP_PID

        # 파일 삭제 및 재생성
        rm -f /tmp/tcpdump.pcap && touch /tmp/tcpdump.pcap

        # TCPDump 다시 시작
        start_tcpdump
    fi
done
