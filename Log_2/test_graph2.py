import os
import re
from graphviz import Digraph

# 노드 이름을 얻기 위한 함수
def get_node_name(function_name, pid):
    return pid_info_maps.get(function_name, {}).get(pid, None)

# 노드 이름으로 PID를 찾는 함수
def find_pid_by_node_name(function_name, target_node_name):
    for pid, node_name in pid_info_maps.get(function_name, {}).items():
        if node_name == target_node_name:
            return pid
    return None

# Kubernetes 서비스 정보를 파일에서 읽는 함수
def read_k8s_services_info(filename):
    service_info = {}
    with open(filename, 'r') as file:
        next(file)  # 첫 줄 건너뛰기
        for line in file:
            if line.strip():  # 비어 있지 않은 줄 체크
                parts = line.split(':')
                if len(parts) > 1:
                    name = parts[0].strip()
                    ip = parts[1].strip().split(' ')[0]  # 첫 번째 IP 가져오기
                    ports_info = parts[2].strip().split(' ')
                    for port_info in ports_info:
                        port = port_info.strip().split('/')[0]  # 포트 번호 가져오기
                        if port:  # 포트가 비어 있지 않은 경우
                            ip_port = f"{ip}_{port}"  # ip:port 형식으로 결합
                            service_info[ip_port] = name  # 중복 체크는 이제 아래에서 처리

    # 중복된 ip:port 제거
    unique_service_info = {}
    for ip_port, name in service_info.items():
        if ip_port not in unique_service_info:  # 중복 체크
            unique_service_info[ip_port] = name

    return unique_service_info



# IP와 포트로 Kubernetes 서비스 이름을 찾는 함수
def find_service_name(ip_port):
    return k8s_services_info.get(ip_port, None)

# 함수 목록 파일 경로
function_list_file = "function_list"

# 로그 파일 패턴 (예: function_name.log.52754)
log_file_pattern = r"(.*)\.log\.(\d+)"

# 모니터링할 파일 목록
open_monitoring_files = [
    "node_modules",
    "/etc/localtime",
    "/home/app/index.js",
    "/usr/local/bin/node",
    "/dev/urandom",
    "/dev/null",
    "/usr/lib/libgcc_s.so.1",
    "/usr/lib/libstdc++.so.6",
    "/home/app/handler.js",
    "/etc/resolv.conf"
]

# Kubernetes 서비스 정보 읽기
k8s_services_info = read_k8s_services_info("k8s_services_info")

# 그래프 초기화
graph = Digraph('G', filename='system_call_graph', format='png')
subgraphs = {}
pid_info_maps = {}
nodes_exist_check = set()
# Kubernetes 서비스 정보를 그래프에 추가
for ip_port, service_name in k8s_services_info.items():
    nodes_exist_check.add(ip_port)

# 함수 목록 파일 읽기
with open(function_list_file, 'r') as f:
    function_list = f.read().splitlines()

# 각 함수 폴더에 대한 그래프 생성
for function_name in function_list:
    folder_path = os.path.join(function_name)
    
    pid_info_maps[function_name] = {}

    # PID와 노드 이름 매핑 정보 읽기
    with open(f"{folder_path}/tid_info.txt", 'r') as f:
        for line in f:
            node_name, pid = line.strip().split('/')
            pid_info_maps[function_name][pid] = node_name
    
    # 서브그래프 생성
    subgraph = Digraph(f'cluster_{function_name}')
    subgraph.attr(label=function_name)

    # 각 PID와 노드 이름을 서브그래프에 추가
    for pid, node_name in pid_info_maps.get(function_name, {}).items():
        subgraph.node(name=f'{pid}', label=f'{node_name}')
        
        # 로그 파일 경로 구성
        parts = function_name.split('-')
        result = '-'.join(parts[:-2])
        log_file_path = f"{folder_path}/{result}_syscalls.log.{pid}"
        
        # 로그 파일이 존재하고, 크기가 0보다 큰 경우에만 처리
        if os.path.exists(log_file_path) and os.path.getsize(log_file_path) > 0:
            with open(log_file_path, 'r') as log_file:
                for line in log_file:
                    # 시스템 콜 로그에서 필요한 정보를 추출
                    syscall_match = re.search(r'(\w+)\((.*)\)\s+=\s+(-?\d+)(?:\s+(\w+)\s+\((.*)\))?', line)
                    if syscall_match:
                        syscall_name = syscall_match.group(1)
                        syscall_args = syscall_match.group(2)
                        result_pid = syscall_match.group(3)
                        # clone 처리
                        if syscall_name == "clone":
                            clone_thread_pid = find_pid_by_node_name(function_name, result_pid)
                            subgraph.edge(f'{pid}', f'{clone_thread_pid}', label=syscall_name)

                        # execve 처리
                        if syscall_name == "execve":
                            subgraph.node(f'exec_{pid}', syscall_args)
                            subgraph.edge(f'{pid}', f'exec_{pid}', label=syscall_name)

                        # open 처리
                        if syscall_name == "open":
                            file_name = re.findall(r'"([^"]+)"', syscall_args)[0]
                            if file_name in open_monitoring_files:
                                subgraph.node(name=f'{function_name}_{file_name}', label=f'{file_name}')
                                subgraph.edge(f'{pid}', f'{function_name}_{file_name}', label="read")

                        # recvfrom 처리
                        if syscall_name == "recvfrom":
                            ip_port_pattern = r'sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d\.]+)"\)'
                            match = re.search(ip_port_pattern, syscall_args)
                            if match:
                                ip_address = match.group(2)
                                port_number = match.group(1)
                                ip_port = f"{ip_address}_{port_number}"
                                if ip_port in nodes_exist_check:
                                    graph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    graph.edge(f'{ip_port}', f'{pid}', label=syscall_name)
                                else:
                                    subgraph.node(f'{ip_port}', label=ip_port)
                                    graph.edge(f'{ip_port}', f'{pid}', label=syscall_name)

                        # sendto 처리
                        if syscall_name == "sendto":
                            ip_port_pattern = r'sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d\.]+)"\)'
                            match = re.search(ip_port_pattern, syscall_args)
                            if match:
                                ip_address = match.group(2)
                                port_number = match.group(1)
                                ip_port = f"{ip_address}_{port_number}"
                                if ip_port in nodes_exist_check:
                                    graph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    graph.edge(f'{pid}',f'{ip_port}', label=syscall_name)
                                else:
                                    subgraph.node(f'{ip_port}', label=ip_port)
                                    graph.edge(f'{pid}',f'{ip_port}', label=syscall_name)
                                    
                        if syscall_name == "connect":
                            ip_port_pattern = r'sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d\.]+)"\)'
                            match = re.search(ip_port_pattern, syscall_args)
                            if match:
                                ip_address = match.group(2)
                                port_number = match.group(1)
                                ip_port = f"{ip_address}_{port_number}"
                                if ip_port in nodes_exist_check:
                                    graph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    graph.edge(f'{pid}',f'{ip_port}', label=syscall_name, dir='both')
                                else:
                                    subgraph.node(f'{ip_port}', label=ip_port)
                                    graph.edge(f'{pid}',f'{ip_port}', label=syscall_name, dir='both')
                        # gateway 관련 처리
                        # if 'gateway' in syscall_args:
                        #     subgraph.edge(f'{pid}', 'gateway', label=f'{syscall_name}-{pid}')
    
    # 함수별 서브그래프 추가
    graph.subgraph(subgraph)
    subgraphs[function_name] = subgraph

# 최종 그래프 저장
graph.render('system_call_graph')
