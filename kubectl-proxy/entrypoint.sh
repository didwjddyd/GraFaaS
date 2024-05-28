#!/bin/sh

# tcpdump를 백그라운드에서 실행
tcpdump -i eth0 -w /tmp/tcpdump.pcap &

# tcpdump.pcap 파일이 생성될 때까지 기다림
while [ ! -f /tmp/tcpdump.pcap ]; do
    sleep 1
done

# tcpdump 파일이 업데이트될 때마다 스크립트 실행
while inotifywait -e modify /tmp/tcpdump.pcap; do
    python3 /tmp/convert_log.py
done

