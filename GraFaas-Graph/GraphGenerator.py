import networkx as nx
import matplotlib.pyplot as plt

import LogParser

fileName = 'test_logs.txt'

try:
    sessionList = LogParser.LogToSessions(fileName)
    G = nx.Graph()
    subGraphs = []
    for session in sessionList:
        subGraph = nx.Graph()
        subGraph.add_nodes_from([session[0][0], session[0][1]])
        subGraph.add_edge(session[0][0], session[0][1])
        subGraphs.append(subGraph)
        G = nx.compose(G, subGraph)

    pos = {}
    x_offset = 0
    fixed_offset = 2.0
    for subGraph in subGraphs:
        subGraphPos = nx.spring_layout(subGraph, seed=1700)
        
        for node, position in subGraphPos.items():
            pos[node] = (position[0] + x_offset, position[1])

        x_offset += fixed_offset
 
    plt.figure(figsize=(10, 8))
    nx.draw(G, pos, with_labels=True, font_size=10)
    plt.title('test')
    plt.show()
except Exception as e:
    print(e)