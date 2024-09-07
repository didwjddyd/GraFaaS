# chatgpt initial code
from logging import exception
import networkx as nx
import matplotlib.pyplot as plt

def parse_log_file(log_filename):
    # Initialize variables
    log_data = []
    current_block = {}
    in_block = False
    all_network_syscall = ("socket", "connect", "accept4", "getsockname",
                           "getpeername", "setsockopt", "getsockopt",
                           "epoll_pwait", "epoll_ctl")

    network_syscall = ("accept4", "getsockname", "getpeername")

    alastor_syscall = ("socket", "connect", "accept4", "execve", "clone",
                       "open", "bind", "listen", "fork", "sendto", "recvfrom",
                       "chmod", "chown", "access", "unlink", "unlinkat")

    # Open and read the log file
    with open(log_filename, 'r') as file:
        for line in file:
            # line = line.strip()
            # if line.split(' ')[1].startswith(alastor_syscall):
            #     print(' '.join(line.split(' ')[1:]))
            line = line.strip()
            if line.split(' ')[1].startswith("accept4"):
                syscall_line = " ".join(line.split(' ')[1:])
                syscall_split = syscall_line.split(', ')
                is_not_eagain = 'EAGAIN' not in syscall_split[3]
                
                if is_not_eagain:
                    try:
                        socket_desc = syscall_split[0].split('(')[-1]
                        port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
                        ip_addr = syscall_split[5].split('ffff')[-1][1:-1]
                        return_desc = syscall_split[-1].split(' = ')[-1]
                        print(f"accept4    : {socket_desc}, {ip_addr}:{port_num} = {return_desc}")
                    except Exception as e:
                        print(log_filename , syscall_line)
                        print(e)
                    finally:
                        data_tup = ('accept4', f'{ip_addr}:{port_num}')
                        if data_tup not in log_data:
                            log_data.append(('accept4', f'{ip_addr}:{port_num}'))
            elif line.split(' ')[1].startswith("socket"):
                pass
    #         elif line.split(' ')[1].startswith("getsockname"):
    #             syscall_line = " ".join(line.split(' ')[1:])
    #             syscall_split = syscall_line.split(', ')
    #             is_inet6 = 'AF_INET6' in syscall_split[1]

    #             if is_inet6:
    #                 try:
    #                     socket_desc = syscall_split[0].split('(')[-1]
    #                     port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
    #                     ip_addr = syscall_split[5].split('ffff')[-1][1:-1]
    #                     print(f"getsockname: {socket_desc}, {ip_addr}:{port_num}")
    #                 except Exception as e:
    #                     print(log_filename , syscall_line)
    #                     print(e)
    #                 finally:
    #                     if socket_desc in log_data:
    #                         log_data[socket_desc].append(('getsockname', f'{ip_addr}:{port_num}'))
    #                     else:
    #                        log_data[socket_desc] = [(('getsockname', f'{ip_addr}:{port_num}'))]
    #             else:
    #                 try:
    #                     socket_desc = syscall_split[0].split('(')[-1]
    #                     port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
    #                     ip_addr = syscall_split[3].split('(')[-1][1:-3]
    #                     print(f"getsockname: {socket_desc}, {ip_addr}:{port_num}")
    #                 except Exception as e:
    #                     print(log_filename , syscall_line)
    #                     print(e)
    #                 finally:
    #                     if socket_desc in log_data:
    #                         log_data[socket_desc].append(('getsockname', f'{ip_addr}:{port_num}'))
    #                     else:
    #                         log_data[socket_desc] = [(('getsockname', f'{ip_addr}:{port_num}'))]
    #         elif line.split(' ')[1].startswith("getpeername"):
    #             syscall_line = " ".join(line.split(' ')[1:])
    #             syscall_split = syscall_line.split(', ')
    #             is_inet6 = 'AF_INET6' in syscall_split[1]

    #             if is_inet6:
    #                 try:
    #                     socket_desc = syscall_split[0].split('(')[-1]
    #                     port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
    #                     ip_addr = syscall_split[5].split('ffff')[-1][1:-1]
    #                     print(f"getpeername: {socket_desc}, {ip_addr}:{port_num}")
    #                 except Exception as e:
    #                     print(log_filename , syscall_line)
    #                     print(e)
    #                 finally:
    #                     if socket_desc in log_data:
    #                         log_data[socket_desc].append(('getpeername', f'{ip_addr}:{port_num}'))
    #                     else:
    #                        log_data[socket_desc] = [(('getpeername', f'{ip_addr}:{port_num}'))]
    #             else:
    #                 try:
    #                     socket_desc = syscall_split[0].split('(')[-1]
    #                     port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
    #                     ip_addr = syscall_split[3].split('(')[-1][1:-3]
    #                     print(f"getpeername: {socket_desc}, {ip_addr}:{port_num}")
    #                 except Exception as e:
    #                     print(log_filename , syscall_line)
    #                     print(e)
    #                 finally:
    #                     if socket_desc in log_data:
    #                         log_data[socket_desc].append(('getpeername', f'{ip_addr}:{port_num}'))
    #                     else:
    #                        log_data[socket_desc] = [(('getpeername', f'{ip_addr}:{port_num}'))]

    return log_data

def create_accept_graph(data, root_node="container"):
    # 방향성 있는 그래프 생성
    G = nx.DiGraph()

    # 루트 노드 추가
    G.add_node(root_node)

    # 데이터를 순회하면서 IP:포트 노드 및 간선 추가
    for syscall, ip_port in data:
        port = ip_port.split(':')[-1]  # 포트 추출
        edge_label = f"accept-{port}"  # 간선 레이블 생성
        G.add_edge(root_node, ip_port, label=edge_label)

    # 그래프 레이아웃 설정
    pos = nx.spring_layout(G)  # seed는 레이아웃의 일관성을 위해 사용됩니다.

    # 그래프 그리기
    plt.figure(figsize=(12, 10))
    nx.draw(G, pos, with_labels=True, node_color='lightblue', node_size=2000, font_size=10, font_weight='bold', arrowstyle='->', arrowsize=20)

    # 간선 레이블 추가
    edge_labels = nx.get_edge_attributes(G, 'label')
    nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_color='red')

    # 그래프 저장
    filename = root_node + "_graph.png"
    plt.title("Accept Network Graph")
    plt.savefig(filename, format='png')
    print(f"Graph saved as {filename}")

    # 그래프 표시
    #plt.show()

# Main execution
log_filename = [
    "product-purchase_syscalls.log", "product-purchase-get-price_syscalls.log",
    "product-purchase-authorize-cc_syscalls.log",
    "product-purchase-publish_syscalls.log"
]

for file_name in log_filename:
    print(file_name)
    log_data = parse_log_file('log/' + file_name)
    create_accept_graph(log_data, root_node=file_name)