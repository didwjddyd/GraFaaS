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
    
    strace -ttt -q -o /tmp/${CONTAINER_NAME}/${LOG_NAME}_syscalls.log -e trace=execve,fork,clone,open,socket,bind,listen,accept4,connect,sendto,recvfrom,chmod,chown,access,unlink,unlinkat -ff -p $TARGET_PID &
    STRACE_PID=$!
    echo -e "Started strace for *$CONTAINER_NAME* with PID: $STRACE_PID at PID: $TARGET_PID \n"
}

# 프로세스 상태를 감시하는 함수
monitor_processes() {
    # 이미 strace를 시작한 PID를 저장할 배열
    declare -a traced_pids
    declare -a dir_names
    touch /tmp/test.txt
    # 무한 루프를 돌며 프로세스를 감시
    while true; do
        # fwatchdog와 index.js 프로세스의 PID 목록 추출
        fwatchdog_pids=$(pgrep -f "fwatchdog")
        pids=$(pgrep -f "index")

        if [ -z "$fwatchdog_pids" ]; then
            sleep 0.05
            continue
        fi
        
        for fwatchdog_pid in $fwatchdog_pids; do
            func_name=$(cat /proc/$fwatchdog_pid/environ | tr '\0' '\n' | grep '^HOSTNAME=' | cut -d '=' -f 2)
            if [ -z "$func_name" ]; then
                echo "Can not find function name to mkdir in PID $fwatchdog_pid."
                continue
            fi
            
            if [[ ! " ${dir_names[@]} " =~ " $func_name " ]]; then
                LOG_DIR="/tmp/${func_name}"
                OUTPUT_FILE="/tmp/test.txt"
                mkdir -p "$LOG_DIR"
                
                LOG_NAME=$(echo "$func_name" | awk -F- '{OFS="-"; NF-=2; print}')
                
                {
                    # inotifywait로 새로운 로그 파일 생성 감지
                    inotifywait -m -e create "$LOG_DIR" --format '%f' |
                    while read NEW_LOG_FILE; do
                        echo "New log file detected: $LOG_DIR/$NEW_LOG_FILE"
                        if [[ $NEW_LOG_FILE == ${LOG_NAME}_syscalls.log.* ]]; then
                            # tail -f로 새로운 로그 파일을 모니터링합니다.
                            {
                                tail -f "$LOG_DIR/$NEW_LOG_FILE" | awk -v log_dir="$LOG_DIR" -v output_file="/tmp/test.txt" -f /tmp/Catch_clone.awk
                            } &

                        fi
                    done
                } &

                echo "$fwatchdog_pid" > "$LOG_DIR/fwatchdog_pid"
                dir_names+=("$func_name")
                echo -e "\nDetected fwatchdog process with PID $fwatchdog_pid for *$func_name*. Make dir complete."
            fi
        done
        
        # PID가 없으면 계속 진행
        if [ -z "$pids" ]; then
            sleep 0.05
            continue
        fi
        
        for pid in $pids; do
            func_name=$(cat /proc/$pid/environ | tr '\0' '\n' | grep '^HOSTNAME=' | cut -d '=' -f 2)

            # func_name이 없으면 무시하고 다음 PID로 이동
            if [ -z "$func_name" ]; then
                echo "PID $pid에서 HOSTNAME을 찾을 수 없습니다."
                continue
            fi

            # strace PID 확인
            STRACE_PID=$(pgrep -f "strace -ttt -p $pid")
            if [ -z "$STRACE_PID" ]; then
                # strace가 실행 중이지 않은 경우
                if [[ ! " ${traced_pids[@]} " =~ " $pid " && -d "$LOG_DIR" ]]; then
                    echo "Detected new process with PID $pid for *$func_name*. Starting strace..."
                    # strace 실행
                    start_strace $pid "$func_name"
                    traced_pids+=("$pid")
                fi
            fi
        done

        # 0.05초마다 반복
        sleep 0.05
    done
}

nginx -g 'daemon off;' &

# DebugFS 마운트
mount_debugfs

# TCPDump 시작
start_tcpdump

# 프로세스 감시 함수 호출
monitor_processes &

# 무한 루프를 돌며 프로세스 상태를 감시
while true; do
    if ! kill -0 $TCPDUMP_PID 2>/dev/null; then
        echo "tcpdump process has exited. Restarting..."
        start_tcpdump
    fi
    sleep 10
done
