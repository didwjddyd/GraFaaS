# chatgpt initial code
import networkx as nx
import matplotlib.pyplot as plt

def parse_log_file(log_filename):
    # Initialize variables
    log_data = []
    current_block = {}
    in_block = False
    network_syscall = (
        "socket", "connect",
        "accept4", "getsockname",
        "getpeername", "setsockopt",
        "getsockopt","epoll_pwait",
        "epoll_ctl" 
    )

    # Open and read the log file
    with open(log_filename, 'r') as file:
        for line in file:
            line = line.strip()
            if line.split(' ')[1].startswith(network_syscall):
                log_data.append(" ".join(line.split(' ')[1:]))
    
    # Add the last block if present
    if in_block and current_block:
        log_data.append(current_block)
    
    return log_data

def create_graph_from_log(log_data):
    G = nx.DiGraph()

    for block in log_data:
        source_port = block['source_port']
        destination_port = block['destination_port']
        syscalls = block['syscalls']

        if source_port and destination_port:
            for syscall in syscalls:
                G.add_edge(source_port, destination_port, label=syscall)

    return G

def plot_graph(G):
    pos = nx.spring_layout(G, k=3)  # k 값을 설정하여 노드 간의 간격을 조정
    labels = nx.get_edge_attributes(G, 'label')

    # 그래프 그리기
    fig, ax = plt.subplots(figsize=(14, 10))

    nx.draw(G, pos, with_labels=True, ax=ax, node_size=800, node_color="skyblue", font_size=9, font_color="black", font_weight="bold", edge_color="gray", linewidths=1, arrows=True)
    
    # 축 범위를 설정하여 그래프를 축소
    # ax.set_xlim(-1.25, 1.25)
    # ax.set_ylim(-1.25, 1.25)
    
    nx.draw_networkx_edge_labels(G, pos, edge_labels=labels)
    plt.title('Syscall Network Graph')
    # plt.show()
    plt.savefig("bpftrace_graph.png")

# Main execution
log_filename = [
    "product-purchase_syscalls.log",
    "product-purchase-get-price_syscalls.log",
    "product-purchase-authorize-cc_syscalls.log",
    "product-purchase-publish_syscalls.log"
]
log_data = parse_log_file('log/' + log_filename[0])
for i in log_data:
    print(i)
# G = create_graph_from_log(log_data)
# plot_graph(G)
