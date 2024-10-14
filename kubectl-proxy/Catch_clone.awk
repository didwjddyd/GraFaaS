{
    # clone 함수 호출 여부를 확인하고, clone 결과값을 추출
    if ($0 ~ /clone\(/) {
        # clone 결과값이 마지막 필드에 위치 (예: = 24)
        clone_result = $NF;
        sub(/^=/, "", clone_result);  # '=' 제거
        clone_result = clone_result + 0;  # 정수형 변환

        # echo를 통해 확인 메시지 출력
        system("echo 'Clone detected, result: " clone_result "'")

        # clone 발생 시점의 타임스탬프 기록
        system("date +%s > /tmp/clone_timestamp")
        getline clone_timestamp < "/tmp/clone_timestamp"

        # clone 발생 시점 이후에 생성되는 로그 파일을 차례대로 연결
        while (1) {
            cmd = "find " log_dir " -type f -newermt @" clone_timestamp " | head -1"
            cmd | getline NEW_LOG_FILE
            close(cmd)

            # 새로 생성된 로그 파일을 찾을 때까지 대기
            if (NEW_LOG_FILE != "") {
                # 로그 파일 이름에서 숫자를 추출
                split(NEW_LOG_FILE, parts, "\\.");
                last_number = parts[length(parts)];  # 마지막 숫자를 추출

                # 결과를 출력 파일에 저장
                printf("Clone Result: %s, New Log File: %s, Last Number: %s\n", clone_result, NEW_LOG_FILE, last_number) >> output_file;

                # 로그 파일을 처리했으므로 루프 탈출
                break;
            }

            # 잠시 대기 후 재시도 (로그 파일 생성을 기다림)
            system("sleep 0.1")
        }
    }
}
