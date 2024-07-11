import re
import networkx as nx
import matplotlib.pyplot as plt
from scapy.all import rdpcap, TCP

def parse_http_payload(payload):
    lines = payload.strip().split("\n")
    first_line = lines[0]
    method, path, _ = first_line.split(" ", 2)
    return method, path

# .pcap 파일 읽기
packets = rdpcap('tcpdump.pcap')

http_requests = []

# 패킷에서 HTTP 요청 페이로드 추출
for packet in packets:
    if packet.haslayer(TCP) and packet[TCP].dport == 80:
        try:
            payload = bytes(packet[TCP].payload).decode('utf-8')
            if payload.startswith('POST') or 'HTTP/1.' in payload:
                http_requests.append(payload)
        except UnicodeDecodeError:
            continue

# HTTP 요청을 파싱하여 메서드와 경로 추출
parsed_requests = []
for request in http_requests:
    try:
        parsed_requests.append(parse_http_payload(request))
    except:
        continue

# logs.txt 파일에 HTTP 요청 메서드와 경로를 추가하기 (추가 모드로)
with open('logs.txt', 'a') as file:
    for method, path in parsed_requests:
        file.write(f"{method} {path}\n")

# 그래프 생성
G = nx.DiGraph()

for i in range(0, len(parsed_requests), 2):
    request1 = parsed_requests[i]
    if i + 1 < len(parsed_requests):
        request2 = parsed_requests[i + 1]
    else:
        break
    
    method1, path1 = request1
    method2, path2 = request2
    
    G.add_edge((method1, path1), (method2, path2))

# 그래프 그리기
fig, ax = plt.subplots(figsize=(14, 10))

pos = nx.spring_layout(G, k=3)  # k 값을 설정하여 노드 간의 간격을 조정

nx.draw(G, pos, with_labels=True, ax=ax, node_size=800, node_color="skyblue", font_size=9, font_color="black", font_weight="bold", edge_color="gray", linewidths=1, arrows=True)

# 축 범위를 설정하여 그래프를 축소
ax.set_xlim(-1.5, 1.5)
ax.set_ylim(-1.5, 1.5)

plt.title("Function Call Graph from pcap HTTP Requests")
plt.show()
