import re
import networkx as nx
import matplotlib.pyplot as plt
from scapy.all import rdpcap, TCP, IP, IPv6

def extract_http_payload(packet):
    try:
        payload = bytes(packet[TCP].payload).decode('utf-8')
        if payload.startswith('POST') or 'HTTP/1.' in payload:
            return payload
    except UnicodeDecodeError:
        return None

def parse_http_payload(payload):
    lines = payload.strip().split("\n")
    first_line = lines[0]
    method, path, _ = first_line.split(" ", 2)
    return method, path

def get_host(request):
    lines = request.strip().split("\n")
    line = [s for s in lines if "Host:" in s or "host:" in s]
    host = line[0].split(' ')[1]

    return host

# .pcap 파일 읽기
packets = rdpcap('tcpdump.pcap')

http_requests = []

# 패킷에서 HTTP 요청 페이로드 추출
for packet in packets:
    if packet.haslayer(TCP) and packet[TCP].dport == 80:
        payload = extract_http_payload(packet)
        if payload:
            http_requests.append((packet, payload))

# logs.txt 파일에 HTTP 요청 전체 페이로드와 패킷 정보를 추가하기 (추가 모드로)
with open('logs.txt', 'w') as file:
    for packet, request in http_requests:
        if packet.haslayer(IP):
            src_ip = packet[IP].src
            src_port = packet[TCP].sport
            dst_ip = packet[IP].dst
            dst_port = packet[TCP].dport
        elif packet.haslayer(IPv6):
            src_ip = packet[IPv6].src
            src_port = packet[TCP].sport
            dst_ip = packet[IPv6].dst
            dst_port = packet[TCP].dport
        else:
            continue

        file.write(f"Source IP: {src_ip}, Source Port: {src_port}, Destination IP: {dst_ip}, Destination Port: {dst_port}\n")
        file.write(f"Payload:\n{request}\n\n")

# 그래프 생성
G = nx.DiGraph()

# 초기 구현.
# for i in range(0, len(http_requests), 2):
#     request1 = http_requests[i][1]
#     if i + 1 < len(http_requests):
#         request2 = http_requests[i + 1][1]
#     else:
#         break

#     method1, path1 = parse_http_payload(request1)
#     method2, path2 = parse_http_payload(request2)

#     print(f"method1: {method1}")
#     print(f"path1: {path1}")
#     print(f"method2: {method2}")
#     print(f"path2: {path2}\n")

#     G.add_edge((method1, path1), (method2, path2))

# 그래프 노드 매핑
nodes = []
startPoint = []
mapping = {}
for request in http_requests:
    method, path = parse_http_payload(request[1])
    host = get_host(request[1])

    nodes.append((method, path))

    if mapping.get((method, path)) == None:
        mapping[(method, path)] = 1
    else:
        mapping[(method, path)] += 1

    if "nginx-proxy-service" not in host:
        startPoint.append((method, path))

# print(nodes)
# print(startPoint)
# print(mapping)

# 그래프 노드 추가
for i in range(0, len(nodes) - 1):
    node1 = nodes[i]
    node2 = nodes[i + 1]

    print(node1)
    print(node2)

    if node2 in startPoint:
        print("no edge")
        continue
    elif mapping.get(node1) < 0 or mapping.get(node2) < 0:
        continue
    else:
        G.add_edge(node1, node2)

        mapping[node1] -= 1
        mapping[node2] -= 1

        print()
    
# 그래프 그리기
fig, ax = plt.subplots(figsize=(14, 10))

pos = nx.spring_layout(G, k=3)  # k 값을 설정하여 노드 간의 간격을 조정

nx.draw(G, pos, with_labels=True, ax=ax, node_size=800, node_color="skyblue", font_size=9, font_color="black", font_weight="bold", edge_color="gray", linewidths=1, arrows=True)

# 축 범위를 설정하여 그래프를 축소
ax.set_xlim(-1.5, 1.5)
ax.set_ylim(-1.5, 1.5)

plt.title("Function Call Graph from pcap HTTP Requests")

# 이미지 파일로 저장
plt.savefig('http_requests_graph.png')
