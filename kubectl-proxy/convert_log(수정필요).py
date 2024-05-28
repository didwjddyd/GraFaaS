from scapy.all import rdpcap
from datetime import datetime

# 파일 경로 정의
pcap_file_path = "/tmp/tcpdump.pcap"
log_file_path = "/tmp/logs.txt"

# 현재 시간 기록
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def process_packet(packet, stack, log_file):
    packet_str = packet.show(dump=True)
    process_log_line(packet_str, stack, log_file)

def process_log_line(line, stack, log_file):
    log_str = ""
    in_quotes = False
    quote_char = ""
    
    for i in line:
        if i in ['"', "'"]:
            if in_quotes and i == quote_char:
                in_quotes = False
                quote_char = ""
            elif not in_quotes:
                in_quotes = True
                quote_char = i
            log_str += i
        elif i == '{' or i == '[':
            print_log_text(log_str, stack, log_file)
            stack.append(i)
            log_str = ""
        elif i == '}' or i == ']':
            print_log_text(log_str, stack, log_file)
            stack.pop()
            log_str = ""
        else:
            log_str += i

    if log_str:
        print_log_text(log_str, stack, log_file)

def print_log_text(log_str, stack, log_file):
    text = ""
    in_quotes = False
    quote_char = ""
    
    for char in log_str:
        if char in ['"', "'"]:
            if in_quotes and char == quote_char:
                in_quotes = False
                quote_char = ""
            elif not in_quotes:
                in_quotes = True
                quote_char = char
            text += char
        elif char == ',' and not in_quotes:
            if len(text.strip()) > 0:
                write_log(text, stack, log_file)
            text = ""
        else:
            text += char

    if len(text.strip()) > 0:
        write_log(text, stack, log_file)

def write_log(log_txt, stack, log_file):
    if len(stack) > 0 and len(log_txt.strip()) > 1:
        log_file.write('\u2520')
    if log_txt.strip():
        for _ in range(len(stack)):
            log_file.write("--")
        if len(log_txt.strip()) > 1:
            log_file.write(f"{log_txt.strip()}\n")

# 패킷을 읽고 로그 파일에 기록
packets = rdpcap(pcap_file_path)
with open(log_file_path, 'a') as log_file:
    log_file.write(f"{now_time}\n")
    stack = []
    for packet in packets:
        process_packet(packet, stack, log_file)
