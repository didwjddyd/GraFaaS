import subprocess
from datetime import datetime
# 명령어 정의
command = "faas-cli -g http://localhost:31112 logs product-purchase"

# 로그 파일 경로 정의
log_file_path = "logs.txt"
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# 서브 프로세스를 실행하고 명령어를 실행

def process_log_line(log_file, log_str, stack):
    """로그 문자열 처리 및 파일에 기록"""
    text = log_str.split(",")
    for log_txt in text:
        if len(stack) > 0 and len(log_txt) > 1: log_file.write('\u2520')
        if log_txt:
            for _ in range(len(stack)):
                log_file.write("--")
            if len(log_txt) > 1: log_file.write(f"{log_txt}\n")

def update_stack_and_log_str(i, stack, log_str):
    """스택 업데이트 및 로그 문자열 초기화"""
    if i in '{[':
        stack.append(i)
        log_str = ""
    elif i in '}]':
        stack.pop()
        log_str = ""
    else:
        if i != ' ': log_str += i
    return stack, log_str

def main_process(command, log_file_path, now_time):
    with subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
        with open(log_file_path, 'a') as log_file:
            first_line = True
            stack = []
            log_str = ""
            for line in process.stdout:
                if first_line:
                    log_file.write(f"{now_time}\n")
                    first_line = False
                    continue
                log_line = line.split("stdout: ", 1)[1].strip()
                for i in log_line:
                    if i in '{[' or i in '}]':
                        process_log_line(log_file, log_str, stack)
                        stack, log_str = update_stack_and_log_str(i, stack, log_str)
                    else:
                        log_str += i if i != ' ' else ''
                print(f"{log_line}")

try:
    # 여기에서 'command', 'log_file_path', 'now_time' 값을 적절히 설정해주세요.
    main_process(command, log_file_path, now_time)
except Exception as e:
    print(f"오류 발생: {e}")
