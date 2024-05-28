from scapy.all import rdpcap
from datetime import datetime

# 로그 파일 및 pcap 파일 경로 정의
pcap_file_path = "/tmp/tcpdump.pcap"
log_file_path = "/tmp/logs.txt"

# 현재 시간 기록
now_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def process_packet(packet, log_file):
    # 패킷 정보를 문자열로 변환하여 로그 파일에 기록
    log_str = packet.summary()
    log_file.write(log_str + "\n")

# 로그 파일을 열고 패킷 처리
with open(log_file_path, 'a') as log_file:
    # 현재 시간을 로그 파일에 기록
    log_file.write(f"{now_time}\n")
    
    # pcap 파일에서 패킷 읽기
    log_file.write("start\n")
    try:
        packets = rdpcap(pcap_file_path)
        # packet_info = packets.show2(dump=True)
        # log_file.write(f"{packets.show(dump=True)}\n")
        # 각 패킷에 대해 처리
        for packet in packets:
            log_file.write(f"{packet.show2(dump=True)}\n")
        for packet in packets:
            process_packet(packet, log_file)
    except Exception as e:
        log_file.write(f"Error reading pcap file: {e}\n")
    log_file.write("end\n")
