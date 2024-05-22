import subprocess
from datetime import datetime

# 명령어 정의
command = "faas-cli -g http://localhost:31112 logs product-purchase"

# 로그 파일 경로 정의
log_file_path = "logs.txt"

# 현재 시간 기록
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def process_log_line(line, stack, log_file):
    log_str = ""
    in_quotes = False
    quote_char = ""
    
    for i in line:
        if i in ['"', "'"]:
            # 따옴표 처리
            if in_quotes and i == quote_char:
                in_quotes = False
                quote_char = ""
            elif not in_quotes:
                in_quotes = True
                quote_char = i
            log_str += i
        elif i == '{' or i == '[':
            # 객체 또는 배열 시작
            print_log_text(log_str, stack, log_file)
            stack.append(i)
            log_str = ""
        elif i == '}' or i == ']':
            # 객체 또는 배열 끝
            print_log_text(log_str, stack, log_file)
            stack.pop()
            log_str = ""
        else:
            log_str += i

    # 남은 log_str 처리
    if log_str:
        print_log_text(log_str, stack, log_file)

def print_log_text(log_str, stack, log_file):
    text = ""
    in_quotes = False
    quote_char = ""
    
    for char in log_str:
        if char in ['"', "'"]:
            # 따옴표 처리
            if in_quotes and char == quote_char:
                in_quotes = False
                quote_char = ""
            elif not in_quotes:
                in_quotes = True
                quote_char = char
            text += char
        elif char == ',' and not in_quotes:
            # 쉼표 처리
            if len(text.strip()) > 0:
                write_log(text, stack, log_file)
            text = ""
        else:
            text += char

    if len(text.strip()) > 0:
        write_log(text, stack, log_file)

def write_log(log_txt, stack, log_file):
    if len(stack) > 0 and len(log_txt.strip()) > 1:
        log_file.write('\u2520')  # 중첩된 로그를 표시하는 선
    if log_txt.strip():
        for _ in range(len(stack)):
            log_file.write("--")  # 중첩 수준에 따라 '--' 추가
        if len(log_txt.strip()) > 1:
            log_file.write(f"{log_txt.strip()}\n")  # 로그 텍스트 기록

# 서브프로세스를 사용하여 명령어 실행
with subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
    with open(log_file_path, 'a') as log_file:
        first_line = True
        stack = []
        for line in process.stdout:
            if first_line:
                log_file.write(f"{now_time}\n")  # 첫 번째 라인에 현재 시간 기록
                first_line = False
                continue
            log_line = line.split("stdout: ", 1)[1].strip()  # 'stdout: ' 이후의 로그 라인 추출
            process_log_line(log_line, stack, log_file)  # 로그 라인 처리
            print(f"{log_line}")  # 콘솔에 로그 라인 출력
