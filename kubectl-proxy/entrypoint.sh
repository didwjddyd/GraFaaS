#!/bin/bash

# DebugFS 마운트
mount_debugfs() {
    if [ ! -d "/sys/kernel/debug" ]; then
        mkdir -p /sys/kernel/debug
    fi
    mount -t debugfs none /sys/kernel/debug
}

# TCPDump를 백그라운드에서 실행하는 함수
start_tcpdump() {
    tcpdump -i eth0 'tcp port 80' -w /tmp/tcpdump.pcap &
    TCPDUMP_PID=$!
    echo "Started tcpdump with PID: $TCPDUMP_PID"
}

# `clone()` 호출을 처리하는 함수
process_clone_calls() {
    local logfile=$1
    local log_dir=$2
    echo "Monitoring clone() calls in $logfile"
    pid=$(basename "$logfile" | sed 's/[^0-9]*//g')
    echo "LOCAL_IP/REMOTE_IP/SOCKET_FD" > "$log_dir/accept4_info.$pid"
    # 로그 파일을 모니터링
    tail -F "$logfile" | while read -r line; do
        if [[ "$line" == *"clone("* ]]; then
            # `clone()`의 반환값 추출
            retval=$(echo "$line" | awk -F' = ' '{print $2}' | awk '{print $1}')
            # `clone_pid` 파일에 추가
            echo "$retval" >> "$log_dir/clone_pid"
        elif [[ "$line" == *"bind"* ]]; then
            BIND_FD=$(echo "$line" | awk -F'[(), ]+' '{for (i=1; i<=NF; i++) if ($i ~ /bind/) print $(i+1)}')
            ((BIND_FD++))
            {
                while true; do
                    sleep 0.05
                    if [[ -e /proc/$pid/fd/$BIND_FD ]]; then
                        SOCKET_LINK=$(readlink /proc/$pid/fd/$BIND_FD)
                        if [[ $SOCKET_LINK =~ socket:\[(.*)\] ]]; then
                            INODE=${BASH_REMATCH[1]}
                            echo "$INODE/$BIND_FD" > $log_dir/inode_value.$pid  # INODE 값을 파일로 저장
                            break
                        fi
                    fi
                done
            } &
        elif [[ "$line" == *"accept4"* ]]; then
            inode_value=$(cat $log_dir/inode_value.$pid | cut -d'/' -f1)
            fd_value=$(cat $log_dir/inode_value.$pid | cut -d'/' -f2)
            accept4_return_value=$(echo $line | cut -d'=' -f2)
            SOCKET_INFO=$(grep -w $inode_value /proc/"$pid"/net/tcp /proc/"$pid"/net/tcp6)
            echo $SOCKET_INFO
            #test
            # echo $(nsenter --target $pid --net netstat -tnlp)
            if [[ $accept4_return_value == *-1* ]]; then 
                continue
            elif [ ! -z "$SOCKET_INFO" ]; then
                echo "$line"
                # IP:PORT 쌍 추출
                pairs=$(echo "$SOCKET_INFO" | grep -oE '([0-9a-fA-F:]+):([0-9A-Fa-f]+)')

                # 결과를 저장할 변수 초기화
                LOCAL_IP_PORT=""
                REMOTE_IP_PORT=""

                # 인덱스 초기화
                index=0

                # IP:PORT 쌍을 반복하며 변환 (앞의 2개만 사용)
                for pair in $pairs; do
                    if [ $index -ge 2 ]; then
                        break
                    fi
                    # IP와 포트 분리
                    IFS=':' read -r ip port <<< "$pair"
                    ip=$(echo "$ip" | sed 's/.*\(.\{8\}\)$/\1/')

                    # IP 변환
                    i4=$(echo "$ip" | cut -c 1-2)   # 01
                    i3=$(echo "$ip" | cut -c 3-4)   # 00
                    i2=$(echo "$ip" | cut -c 5-6)   # 00
                    i1=$(echo "$ip" | cut -c 7-8)   # 7F

                    # 10진수로 변환
                    ip_dec="$((16#$i1)).$((16#$i2)).$((16#$i3)).$((16#$i4))"

                    # 포트 변환 (16진수를 10진수로)
                    port_dec=$((16#$port))

                    # 결과를 변수에 저장
                    if [ $index -eq 0 ]; then
                        LOCAL_IP_PORT="$ip_dec:$port_dec"
                    else
                        REMOTE_IP_PORT="$ip_dec:$port_dec"
                    fi

                    # 인덱스 증가
                    index=$((index + 1))
                done
                
                # 결과 출력
                echo "$LOCAL_IP_PORT/$REMOTE_IP_PORT/$fd_value">> "$log_dir/accept4_info.$pid"
                echo "LOCAL_IP_PORT: $LOCAL_IP_PORT"
                echo "REMOTE_IP_PORT: $REMOTE_IP_PORT"
            else
                echo "No information found in /proc/net/tcp for inode: $INODE"
            fi
        fi
    done 
}


map_pid_clone() {
    for log_dir in /tmp/*/; do
        if [[ -f "$log_dir/clone_pid" ]]; then
            local clone_pids=$(cat "$log_dir/clone_pid")
            local log_file_numbers=()

            # log_file_numbers를 최근 생성 순서대로 정렬
            log_file_numbers=($(ls -lt --time=birth "$log_dir"/*.log.* 2>/dev/null | awk '{print $9}' | sed 's/.*\.log\.//'))

            # log_file_numbers 개수 계산
            local log_count=${#log_file_numbers[@]}
            local clone_pids_count=$(wc -l < "$log_dir/clone_pid")
            # clone_pids는 원래 순서대로 처리
            local index=0
            for retval in $clone_pids; do
                # log_file_numbers를 역순으로 접근
                reverse_index=$(($clone_pids_count-$index-1))
                if [[ -n "${log_file_numbers[reverse_index]}" ]]; then
                    log_file_number="${log_file_numbers[reverse_index]}"
                    echo "$retval/$log_file_number" >> "$log_dir/tid_info.txt"
                    ((index++))
                else
                    break
                fi
            done
        fi
        > "$log_dir/clone_pid"
    done

}

monitor_nginx_requests() {
    local log_file="/var/log/nginx/access.log"
    local last_checked_line=0

    echo "Monitoring Nginx requests in $log_file..."

    while true; do
        if [[ -f "$log_file" ]]; then
            total_lines=$(wc -l < "$log_file")

            if (( total_lines > last_checked_line )); then
                new_requests=$(tail -n +$((last_checked_line + 1)) "$log_file")
                
                while read -r line; do
                    status_code=$(echo "$line" | awk '{print $9}')

                    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
                        echo "detect $status_code"
                        map_pid_clone &
                    fi
                done <<< "$new_requests"

                last_checked_line=$total_lines
            fi
        fi
        sleep 1
    done
}

start_strace() {
    TARGET_PID=$1
    CONTAINER_NAME=$2

    LOG_NAME=$(echo "$CONTAINER_NAME" | awk -F- '{OFS="-"; NF-=2; print}')
    
    strace -ttt -q -o /tmp/${CONTAINER_NAME}/${LOG_NAME}_syscalls.log -s 1024 -e trace=execve,fork,clone,open,socket,bind,listen,accept4,connect,sendto,recvfrom,chmod,chown,access,unlink,unlinkat -ff -p $TARGET_PID &
    STRACE_PID=$!
    echo "node index.js/$TARGET_PID" >> /tmp/${CONTAINER_NAME}/tid_info.txt
    echo -e "Started strace for *$CONTAINER_NAME* with PID: $STRACE_PID at PID: $TARGET_PID \n"
}

monitor_processes() {
    declare -a traced_pids
    declare -a dir_names

    while true; do
        fwatchdog_pids=$(pgrep -f "fwatchdog")
        pids=$(pgrep -f "index")

        if [ -z "$fwatchdog_pids" ]; then
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
                mkdir -p "$LOG_DIR"
                
                {
                    for logfile in $LOG_DIR/*.log*; do
                        if [ -f "$logfile" ]; then
                            process_clone_calls "$logfile" "$LOG_DIR" &
                        fi
                    done
                }&

                {
                    inotifywait -m -e create --format '%w%f' "$LOG_DIR" | while read newfile; do
                        if [[ "$newfile" == *.log* ]]; then
                            echo "New log file detected: $newfile"
                            process_clone_calls "$newfile" "$LOG_DIR" &
                        fi
                    done
                } &

                echo "$fwatchdog_pid" > "$LOG_DIR/fwatchdog_pid"
                dir_names+=("$func_name")
                echo -e "\nDetected fwatchdog process with PID $fwatchdog_pid for *$func_name*. Make dir complete."
            fi
        done

        if [ -z "$pids" ]; then
            continue
        fi
        
        for pid in $pids; do
            func_name=$(cat /proc/$pid/environ | tr '\0' '\n' | grep '^HOSTNAME=' | cut -d '=' -f 2)

            if [ -z "$func_name" ]; then
                echo "PID $pid에서 HOSTNAME을 찾을 수 없습니다."
                continue
            fi

            STRACE_PID=$(pgrep -f "strace -ttt -p $pid")
            if [ -z "$STRACE_PID" ]; then
                if [[ ! " ${traced_pids[@]} " =~ " $pid " && -d "$LOG_DIR" ]]; then
                    echo "Detected new process with PID $pid for *$func_name*. Starting strace..."
                    start_strace $pid "$func_name"
                    # monitor_accept4_socket_info $pid &
                    traced_pids+=("$pid")
                fi
            fi
        done

        sleep 0.01
    done
}

nginx -g 'daemon off;' &
/tmp/tcpdump_gateway.sh &
mount_debugfs
start_tcpdump
monitor_nginx_requests &
monitor_processes &

while true; do
    if ! kill -0 $TCPDUMP_PID 2>/dev/null; then
        echo "tcpdump process has exited. Restarting..."
        start_tcpdump
    fi
    sleep 10
done
