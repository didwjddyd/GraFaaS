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
        subGraph.add_nodes_from([session[0][0][0], session[0][1][0]])
        subGraph.add_edge(session[0][0][0], session[0][1][0])
        subGraphs.append(subGraph)
        G = nx.compose(G, subGraph)

    pos = {}
    # x_offset = 0
    # fixed_offset = 6.0
    # for subGraph in subGraphs:
    #     subGraphPos = nx.spring_layout(subGraph, seed=1700)
    #     for node, position in subGraphPos.items():
    #         pos[node] = (position[0] + x_offset, position[1])

    #     x_offset += fixed_offset

    for i, subGraph in enumerate(subGraphs):
        subGraphPos = nx.spiral_layout(subGraph, resolution=50.0, center=(i * 5, 0))
        pos.update(subGraphPos)
 
    plt.figure(figsize=(30, 6))
    nx.draw(G, pos, with_labels=True, font_size=10)
    plt.title('test')
    plt.savefig('test.png')
    plt.show()
except Exception as e:
    print(e)