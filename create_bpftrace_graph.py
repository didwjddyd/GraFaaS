# chatgpt initial code
from logging import exception
import networkx as nx
import matplotlib.pyplot as plt


def parse_log_file(log_filename):
    # Initialize variables
    log_data = {}
    current_block = {}
    in_block = False
    all_network_syscall = ("socket", "connect", "accept4", "getsockname",
                           "getpeername", "setsockopt", "getsockopt",
                           "epoll_pwait", "epoll_ctl")

    network_syscall = ("accept4", "getsockname", "getpeername")

    # Open and read the log file
    with open(log_filename, 'r') as file:
        for line in file:
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
                        if return_desc in log_data:
                            log_data[return_desc].append(('accept4', f'{ip_addr}:{port_num}'))
                        else:
                            log_data[return_desc] = [(('accept4', f'{ip_addr}:{port_num}'))]
            elif line.split(' ')[1].startswith("getsockname"):
                syscall_line = " ".join(line.split(' ')[1:])
                syscall_split = syscall_line.split(', ')
                is_inet6 = 'AF_INET6' in syscall_split[1]

                if is_inet6:
                    try:
                        socket_desc = syscall_split[0].split('(')[-1]
                        port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
                        ip_addr = syscall_split[5].split('ffff')[-1][1:-1]
                        print(f"getsockname: {socket_desc}, {ip_addr}:{port_num}")
                    except Exception as e:
                        print(log_filename , syscall_line)
                        print(e)
                    finally:
                        if socket_desc in log_data:
                            log_data[socket_desc].append(('getsockname', f'{ip_addr}:{port_num}'))
                        else:
                           log_data[socket_desc] = [(('getsockname', f'{ip_addr}:{port_num}'))]
                else:
                    try:
                        socket_desc = syscall_split[0].split('(')[-1]
                        port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
                        ip_addr = syscall_split[3].split('(')[-1][1:-3]
                        print(f"getsockname: {socket_desc}, {ip_addr}:{port_num}")
                    except Exception as e:
                        print(log_filename , syscall_line)
                        print(e)
                    finally:
                        if socket_desc in log_data:
                            log_data[socket_desc].append(('getsockname', f'{ip_addr}:{port_num}'))
                        else:
                            log_data[socket_desc] = [(('getsockname', f'{ip_addr}:{port_num}'))]
            elif line.split(' ')[1].startswith("getpeername"):
                syscall_line = " ".join(line.split(' ')[1:])
                syscall_split = syscall_line.split(', ')
                is_inet6 = 'AF_INET6' in syscall_split[1]

                if is_inet6:
                    try:
                        socket_desc = syscall_split[0].split('(')[-1]
                        port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
                        ip_addr = syscall_split[5].split('ffff')[-1][1:-1]
                        print(f"getpeername: {socket_desc}, {ip_addr}:{port_num}")
                    except Exception as e:
                        print(log_filename , syscall_line)
                        print(e)
                    finally:
                        if socket_desc in log_data:
                            log_data[socket_desc].append(('getpeername', f'{ip_addr}:{port_num}'))
                        else:
                           log_data[socket_desc] = [(('getpeername', f'{ip_addr}:{port_num}'))]
                else:
                    try:
                        socket_desc = syscall_split[0].split('(')[-1]
                        port_num = ''.join(syscall_split[2].split('(')[-1][:-1])
                        ip_addr = syscall_split[3].split('(')[-1][1:-3]
                        print(f"getpeername: {socket_desc}, {ip_addr}:{port_num}")
                    except Exception as e:
                        print(log_filename , syscall_line)
                        print(e)
                    finally:
                        if socket_desc in log_data:
                            log_data[socket_desc].append(('getpeername', f'{ip_addr}:{port_num}'))
                        else:
                           log_data[socket_desc] = [(('getpeername', f'{ip_addr}:{port_num}'))]

    return log_data

# Main execution
log_filename = [
    "product-purchase_syscalls.log", "product-purchase-get-price_syscalls.log",
    "product-purchase-authorize-cc_syscalls.log",
    "product-purchase-publish_syscalls.log"
]

log_data = parse_log_file('log/' + log_filename[0])
print(log_data)
# for file_name in log_filename:
#     print(file_name)
#     parse_log_file('log/' + file_name)
#     print()
create_syscall_graph(log_data, log_filename[0])