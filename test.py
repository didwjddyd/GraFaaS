import subprocess
from datetime import datetime
# 명령어 정의
command = "faas-cli -g http://localhost:31112 logs product-purchase"

# 로그 파일 경로 정의
log_file_path = "logs.txt"
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# 서브 프로세스를 실행하고 명령어를 실행
with subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
    # 로그 파일을 쓰기 모드로 열기
    # with open(log_file_path, 'a') as log_file:
    #     first_line = True
    #     stack = []
    #     str = ""
    #     for line in process.stdout:
    #         for c in line:
    #             if c=='{' : 
    #                stack.append('{')
    #             elif c=='}' :
    #                 stack.pop()
    #                 parts = str.split('\n')
    #                 for s in parts:
    #                     text = s.split("stdout: ",1)
    #                     for i in range(len(stack)+1) : log_file.write("    ")
    #                     if len(text)>1 : 
    #                         log_file.write(f"{text[1].strip()}\n")
    #                     else : log_file.write(f"{text[0].strip()}\n")
    #                 str = ""
    #             elif c==',' : str+='\n'
    #             elif c!='\'' :str+=c
                
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
                            # log_file.write(f"{len(log_txt)}\n")
                            # if()
                    stack.append(i)
                    log_str=""
                elif i=='}' or i==']' :
                    text = log_str.split(",")
                    for log_txt in text :
                        if log_txt :
                            for j in range(len(stack)) :
                                log_file.write("--")
                            if len(log_txt)>1 : log_file.write(f"{log_txt}\n")
                            # log_file.write(f"{len(log_txt)}\n")
                    stack.pop()
                    log_str = ""
                else : log_str += i
            # if log_line[len(log_line)-1]==':' : log_str += '\n'
            print(f"{log_line}")
                #test
    # with open(log_file_path, 'a') as log_file:
    #     log_start = True
    #     stack = []
    #     str = ""
    #     for line in process.stdout:
    #         if log_start: 
    #             log_file.write(f"{now_time}\n")
    #             log_start=False
    #             continue
    #         log_line = line.split("stdout: ",1)
    #         log_line = log_line[1].strip()
    #         for index in log_line :
    #             if index=='{' or index=='[' :
    #                 text = str.split('\n')
    #                 if len(text)>1 :
    #                     for i in text :
    #                         for j in range(len(stack)) :
    #                             log_file.write("--")
    #                         log_file.write(f"{i}\n")
    #                 stack.append(index)
    #                 str = ""
    #             elif index=='}' or index==']' :
    #                 text = str.split('\n')
    #                 # print(f"{len(stack)}\n{log_line}")
    #                 if len(text)>1 :
    #                     for i in text :
    #                         for j in range(len(stack)) :
    #                             log_file.write("--")
    #                         log_file.write(f"{i}\n")
    #                 str = ""
    #                 stack.pop()
    #             elif index=='\'' or index==' ' :
    #                 continue
    #             elif index==',' :
    #                 str+='\n'
    #             else : str+=index
    #         if log_line[len(log_line)-1]==':' : str+='\n'
    #             # if index == log_line[len(index)-1] : str += '\n'
    #             # str+='\n'