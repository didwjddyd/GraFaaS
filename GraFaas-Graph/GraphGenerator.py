import networkx as nx
import matplotlib.pyplot as plt

import LogParser

fileName = 'test_logs.txt'

try:
    sessionList = LogParser.LogToSessions(fileName)
    G = nx.Graph()
    for session in sessionList:
        subGraph = nx.Graph()
        subGraph.add_nodes_from([session[0][0], session[0][1]])
        subGraph.add_edge(session[0][0], session[0][1])
        G.add_edges_from(subGraph.edges)

    pos = nx.shell_layout(G)
    plt.figure(figsize=(10, 6))
    nx.draw(G, pos, with_labels=True)
    plt.title('test')
    plt.show()
except Exception as e:
    print(e)