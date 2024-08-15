# chatgpt initial code
import networkx as nx
import matplotlib.pyplot as plt

def parse_log_file(log_filename):
    # Initialize variables
    log_data = []
    current_block = {}
    in_block = False
    
    # Open and read the log file
    with open(log_filename, 'r') as file:
        for line in file:
            line = line.strip()
            if line.startswith("Timestamp:"):
                # If there's an active block, add it to the log_data
                if in_block and current_block:
                    log_data.append(current_block)
                # Start a new block
                current_block = {'timestamp': line.split(": ")[1], 'syscalls': [], 'source_port': None, 'destination_port': None}
                in_block = True
            elif line.startswith("Source port:"):
                current_block['source_port'] = line.split(": ")[1]
            elif line.startswith("Destination port:"):
                current_block['destination_port'] = line.split(": ")[1]
            elif line.startswith("Syscall:"):
                syscall = line.split(": ")[-1].split(',')[-1].strip()
                current_block['syscalls'].append(syscall)
    
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
    pos = nx.spring_layout(G)
    labels = nx.get_edge_attributes(G, 'label')
    nx.draw(G, pos, with_labels=True, node_color='lightblue', node_size=2000, font_size=10, font_weight='bold')
    nx.draw_networkx_edge_labels(G, pos, edge_labels=labels)
    plt.title('Syscall Network Graph')
    plt.show()

# Main execution
log_filename = "bpftrace.txt"
log_data = parse_log_file(log_filename)
for i in log_data:
    print(i)
# G = create_graph_from_log(log_data)
# plot_graph(G)
