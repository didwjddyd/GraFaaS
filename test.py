import subprocess
from datetime import datetime
# 명령어 정의
command = "faas-cli -g http://localhost:31112 logs product-purchase"

# 로그 파일 경로 정의
log_file_path = "logs.txt"
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# 서브 프로세스를 실행하고 명령어를 실행
with subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:   
    with open(log_file_path, 'a') as log_file:
        first_line = True
        stack=[]
        log_str = ""
        for line in process.stdout :
            if first_line : 
                log_file.write(f"{now_time}\n")
                first_line = False
                continue
            log_line = line.split("stdout: ",1)[1].strip()
            for i in log_line :
                if i=='{' or i=='[' :
                    text = log_str.split(",")
                    for log_txt in text :
                        if log_txt :
                            for j in range(len(stack)) :
                                log_file.write("--")
                            if len(log_txt)>1 : log_file.write(f"{log_txt}\n")
                    stack.append(i)
                    log_str=""
                elif i=='}' or i==']' :
                    text = log_str.split(",")
                    for log_txt in text :
                        if log_txt :
                            for j in range(len(stack)) :
                                log_file.write("--")
                            if len(log_txt)>1 : log_file.write(f"{log_txt}\n")
                    stack.pop()
                    log_str = ""
                else : log_str += i
            print(f"{log_line}")