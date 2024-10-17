import re

def parse_syscall_log(log_file):
    syscall_log = []
    # 정규식으로 로그를 파싱
    pattern = r"(?P<timestamp>\d+\.\d+)\s(?P<syscall>\w+)\((?P<args>.*?)\)\s=\s(?P<result>[-\d]+|-\d+\s\w+)"
    
    with open(log_file, 'r') as f:
        for line in f :
            match = re.match(pattern,line)
            if match :
                timestamp = match.group('timestamp')
                syscall = match.group('syscall')
                args = match.group('args')
                result = match.group('result')
                syscall_log.append((timestamp, syscall, args, result))
    return syscall_log

log_file = "./product-purchase-86d8dd7f4d-qgzgm/product-purchase_syscalls.log.52754"

parsed = parse_syscall_log(log_file)
if parsed:
    for timestamp, syscall, args, result in parsed :
        print(f"{timestamp},{syscall},{args},{result}\n")
