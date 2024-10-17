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

detect_accept4_socket_info() {
    log_file=$1
    function_name=$2
    pid=$3
    tail -F "$logfile" | while read -r line; do
        if [[ "$line" == *"accept4"* ]]; then
            # 반환된 파일 디스크립터 추출
            FD=$(echo "$line" | awk -F' = ' '{print $2}' | awk '{print $1}')

            echo "Detected accept4 syscall with FD: $FD"

            # 파일 디스크립터의 실제 파일 확인
            SOCKET_LINK=$(readlink /proc/$PID/fd/$FD)
            if [[ $SOCKET_LINK =~ socket:\[(.*)\] ]]; then
                INODE=${BASH_REMATCH[1]}
                echo "Inode: $INODE"

                # /proc/net/tcp에서 해당 inode에 대한 정보 검색
                SOCKET_INFO=$(grep -w $INODE /proc/net/tcp)
                if [ ! -z "$SOCKET_INFO" ]; then
                    # 네트워크 연결 정보 파싱 (ex. Remote IP와 포트)
                    REMOTE_IP_HEX=$(echo $SOCKET_INFO | awk '{print $3}' | cut -d':' -f1)
                    REMOTE_PORT_HEX=$(echo $SOCKET_INFO | awk '{print $3}' | cut -d':' -f2)

                    # IP 주소 및 포트를 사람이 읽을 수 있는 형식으로 변환
                    REMOTE_IP=$(printf "%d.%d.%d.%d\n" $(echo $REMOTE_IP_HEX | sed 's/../0x& /g'))
                    REMOTE_PORT=$(printf "%d\n" 0x$REMOTE_PORT_HEX)

                    echo "Remote IP: $REMOTE_IP"
                    echo "Remote Port: $REMOTE_PORT"
                else
                    echo "No information found in /proc/net/tcp for inode: $INODE"
                fi
            else
                echo "No socket information found for FD: $FD"
            fi
        fi
    done 
}

monitor_accept4_socket_info() {
    pid=$1
    echo "$pid *******"
    {
        declare -A seen_fds

        while true; do
            current_fds=($(ls -l /proc/$pid/fd | awk '{print $9}'))

            for fd in "${current_fds[@]}"; do
                # fd가 존재하지 않으면 continue
                if [ -z "$fd" ]; then
                    continue
                fi
                
                if [[ -z "${seen_fds[$fd]}" ]]; then
                    echo "FD created: $fd"

                    # 해당 fd가 소켓인지 확인
                    link_target=$(readlink "/proc/$pid/fd/$fd")

                    echo "pid: $pid ,,, $fd detected, link target: $link_target"
                    if [[ "$link_target" == socket:* ]]; then
                        echo "Socket detected: $link_target Pid: $pid"

                        # 소켓 inode 추출
                        inode=$(echo "$link_target" | grep -oP '(?<=socket:\[)\d+(?=\])')

                        # /proc/net/tcp 파일에서 inode와 일치하는 소켓 정보 찾기
                        if [[ -n "$inode" ]]; then
                            socket_info=$(grep -w "$inode" /proc/$pid/net/tcp6 /proc/$pid/net/tcp)  # 여기서 경로를 /proc/net/tcp로 유지

                            if [[ -n "$socket_info" ]]; then
                                # 소켓 정보 파싱
                                

                                # # IPv6를 IPv4로 변환하는 부분은 local_ip_port=$(echo "$socket_info" | awk '{print $2}')
                                remote_ip_port=$(echo "$socket_info" | awk '{print $3}')

                                # IP와 포트를 사람이 읽을 수 있는 형식으로 변환
                                local_ip=$(echo "$local_ip_port" | cut -d':' -f1 | sed 's/../&:/g;s/:$//' | xxd -r -p | od -An -tx1 | tr -d ' \n' | sed 's/\(..\)/\1:/g;s/:$//')
                                local_port=$(printf "%d" 0x$(echo "$local_ip_port" | cut -d':' -f2))

                                remote_ip=$(echo "$remote_ip_port" | cut -d':' -f1 | sed 's/../&:/g;s/:$//' | xxd -r -p | od -An -tx1 | tr -d ' \n' | sed 's/\(..\)/\1:/g;s/:$//')
                                remote_port=$(printf "%d" 0x$(echo "$remote_ip_port" | cut -d':' -f2))그대로 유지
                                if [[ "$remote_ip" == "::ffff:"* ]]; then
                                    remote_ip="${remote_ip#::ffff:}"  # Remove ::ffff: prefix
                                    remote_ip=$(echo "$remote_ip" | sed 's/:/./g')
                                fi

                                # 소켓의 원격 IP와 포트 출력
                                echo "$(date '+%Y-%m-%d %H:%M:%S') FD: $fd, Remote IP: $remote_ip, Remote Port: $remote_port"
                            else
                                echo "$(date '+%Y-%m-%d %H:%M:%S') No matching socket info found for inode: $inode"
                            fi
                        fi
                    fi

                    # FD를 seen_fds 배열에 추가
                    seen_fds[$fd]=1
                fi
            done

            # 삭제된 FD 확인
            for fd in "${!seen_fds[@]}"; do
                if [[ ! " ${current_fds[*]} " =~ " $fd " ]]; then
                    echo "FD removed: $fd"
                    unset seen_fds[$fd]
                fi
            done
            sleep 0.01
        done
    } &
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
            echo "$retval"
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

                    # IPv6에서 IPv4로 변환
                    # if [[ "$ip" == *"FFFF"* ]]; then
                    #     ip=$(echo "$ip" | sed 's/^.*FFFF://')  # FFFF 이후의 부분만 남기기
                    # fi
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

        #     else
        #         echo "No socket information found for FD: $FD"
        #     fi
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
