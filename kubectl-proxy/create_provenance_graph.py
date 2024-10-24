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


# 함수 목록 파일 경로
function_list_file = "/tmp/function_list"

# 로그 파일 패턴 (예: function_name.log.52754)
log_file_pattern = r"(.*)\.log\.(\d+)"

# 유저 진입 컨테이너 (예: product-purchase)
user_entrypoint = ""
with open('/tmp/func_call_src_info', 'r') as f:
    for line in f:
        user_entrypoint = line.strip()

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
k8s_services_info = read_k8s_services_info("/tmp/k8s_services_info")
# IP와 포트로 Kubernetes 서비스 이름을 찾는 함수
def find_service_name(ip_port):
    return k8s_services_info.get(ip_port, None)

def find_service_ip_port(service_name):
    for ip_port, name in k8s_services_info.items():
        if name == service_name:
            return ip_port
    return None  # gateway가 없을 경우 None 반환


# 그래프 초기화
graph = Digraph('G', filename='system_call_graph', format='png')
subgraphs = {}
pid_info_maps = {}
nodes_exist_check = set()
external_subgraph = Digraph(f'cluster_services')
external_subgraph.attr(label="external_services")
#Usernode 추가
external_subgraph.node("user", shape="house")

# Kubernetes 서비스 정보를 그래프에 추가
for ip_port, service_name in k8s_services_info.items():
    nodes_exist_check.add(ip_port)

# 함수 목록 파일 읽기
with open(function_list_file, 'r') as f:
    function_list = f.read().splitlines()

# 각 함수 폴더에 대한 그래프 생성
for function_name in function_list:
    folder_path = os.path.join(function_name)
    #clone의 반환값 tid와 host에서의 tid 연결
    pid_info_maps[function_name] = {}
    
    #function_name에서 -로 자른 기준으로 뒤 2개 제거 
    func_name = '-'.join(function_name.split('-')[:-2]).strip()
    print(func_name)
    
    # PID와 노드 이름 매핑 정보 읽기
    folder_path = folder_path.strip()  # 공백 제거
    with open(os.path.join("/tmp", folder_path, "tid_info.txt"), 'r') as f:
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
        log_file_path = f"/tmp/{folder_path.strip()}/{result.strip()}_syscalls.log.{pid}"
        print(log_file_path)
        #accept4 발생했을때의 로컬ip 확인을 위함
        accept4_info = ""
        accept4_info_file_path = f"{folder_path}/accept4_info.{pid}"
        if os.path.exists(accept4_info_file_path):
            with open(accept4_info_file_path, 'r') as f:
                next(f)
                for line in f:
                    accept4_info = line.split('/')[0].strip()
            if accept4_info != "" :
                print(accept4_info)
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
                            match = re.search(r'\["(.*?)"\]', syscall_args)
                            if match:
                                # 쉼표로 나뉜 인수를 추출한 뒤, 각각 공백을 기준으로 합침
                                args_str = match.group(1)
                                args_combined = ' '.join([arg.strip('"') for arg in args_str.split('", "')]) #ex) node index.js
                                subgraph.node(f'{function_name}_{args_combined}', syscall_args)
                                subgraph.edge(f'{pid}', f'{function_name}_{args_combined}', label=syscall_name)

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
                                    external_subgraph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    external_subgraph.edge(f'{ip_port}', f'{pid}', label=syscall_name)
                                else:
                                    external_subgraph.node(f'{ip_port}', label=ip_port)
                                    external_subgraph.edge(f'{ip_port}', f'{pid}', label=syscall_name)

                        # sendto 처리
                        if syscall_name == "sendto":
                            ip_port_pattern = r'sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d\.]+)"\)'
                            match = re.search(ip_port_pattern, syscall_args)
                            if match:
                                ip_address = match.group(2)
                                port_number = match.group(1)
                                ip_port = f"{ip_address}_{port_number}"
                                if ip_port in nodes_exist_check:
                                    external_subgraph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    external_subgraph.edge(f'{pid}',f'{ip_port}', label=syscall_name)
                                else:
                                    external_subgraph.node(f'{ip_port}', label=ip_port)
                                    external_subgraph.edge(f'{pid}',f'{ip_port}', label=syscall_name)
                                    
                        if syscall_name == "connect":
                            ip_port_pattern = r'sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d\.]+)"\)'
                            match = re.search(ip_port_pattern, syscall_args)
                            if match:
                                ip_address = match.group(2)
                                port_number = match.group(1)
                                ip_port = f"{ip_address}_{port_number}"
                                if ip_port in nodes_exist_check:
                                    external_subgraph.node(f'{ip_port}', f'{find_service_name(ip_port)}')
                                    external_subgraph.edge(f'{pid}',f'{ip_port}', label=syscall_name, dir='both')
                                else:
                                    external_subgraph.node(f'{ip_port}', label=ip_port)
                                    external_subgraph.edge(f'{pid}',f'{ip_port}', label=syscall_name, dir='both')
                                    
                        # 보류
                        if syscall_name == "accept4":
                            if func_name == user_entrypoint:
                                subgraph.node(name=f'{func_name}_localhost_3000', label="localhost:3000")
                                external_subgraph.edge('user',f'{func_name}_localhost_3000',label=syscall_name)
                            else :
                                subgraph.node(name=f'{func_name}_localhost_3000', label="localhost:3000")
                                external_subgraph.edge(f"{find_service_ip_port('gateway')}", f'{func_name}_localhost_3000', label=syscall_name)
                            
                            
                        # gateway 관련 처리
                        # if 'gateway' in syscall_args:
                        #     subgraph.edge(f'{pid}', 'gateway', label=f'{syscall_name}-{pid}')
    
    # 함수별 서브그래프 추가
    graph.subgraph(subgraph)
    subgraphs[function_name] = subgraph

graph.subgraph(external_subgraph)
subgraphs["services"] = external_subgraph
# 최종 그래프 저장
graph.render('system_call_graph')
