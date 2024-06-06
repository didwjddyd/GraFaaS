import SessionBlock

def LogToSessions(logFileName:str) -> list:
    tcpdumpLog = __GetTcpdumpLog(logFileName)
    packetList = __ParseTcpdumpLog(tcpdumpLog)
    sessionList = __CreateSessionList(packetList)
    return sessionList

def __GetTcpdumpLog(logFileName:str) -> list:
    try:
        # 패킷 분리
        with open(logFileName, 'r') as file:
            content = file.read()
            packets = content.split('\n\n')
            tcpdumpLog = packets[-1]
            packets.pop()
        return tcpdumpLog
    except Exception as e:
        print(e)

def __ParseTcpdumpLog(tcpdumpLog:list) -> list:
    # tcpdumplog parsing
    # TCP의 src: 요청을 보낸 주소
    # ARP의 src: 요청을 받은 주소
    packetList = []
    try:
        parsedTcpDumpLog = tcpdumpLog.split('\n')
        for line in parsedTcpDumpLog:
            if line == 'end':
                break
            parsedLine = line.split(' ')
            if parsedLine[2] == 'IP':
                #print('IP')
                block = {
                    'type':'IPv4',
                    'proto':parsedLine[4],
                    'src':parsedLine[5].split(':')[0],
                    'sport':parsedLine[5].split(':')[1],
                    'dst':parsedLine[7].split(':')[0],
                    'dport':parsedLine[7].split(':')[1],
                    'flag':parsedLine[8],
                    'hasRaw':True if parsedLine[-1] == 'Raw' else False
                }
                #print(block)
                packetList.append(SessionBlock.TCPPacket(block))
            elif parsedLine[2] == 'ARP':
                #print('ARP')
                block = {
                    'type':'ARP',
                    'op':'is at' if parsedLine[3] == 'is' else 'who has'
                }
                #print(block)
                #packetList.append(block)
            else:
                #print('None')
                block = {
                    'type': parsedLine[-3],
                    'src': parsedLine[0],
                    'dst': parsedLine[2],
                    'hasRaw':True if parsedLine[-1] == 'Raw' else False
                }
                #print(block)
                #packetList.append(block)
        return packetList
    except Exception as e:
        print(e)

def __CreateSessionList(packetList:list) -> list:
    # make session list
    # Prototype: session Class로 대체 예정
    sessionList = [] # Prototype | element: [{}, TCPPacket]
    try:
        for packet in packetList:
            # create session
            sessionNumber = 0
            if len(sessionList) == 0:
                sessionList.append([(packet.GetSrcIp(),packet.GetDstIp())])
            else:
                for i in range(0, len(sessionList)):
                    session = sessionList[i][0]
                    if packet.GetSrcIp() in session and packet.GetDstIp() in session:
                        sessionNumber = i
                        break
                else:
                    sessionList.append([(packet.GetSrcIp(),packet.GetDstIp())])
                    sessionNumber = len(sessionList) - 1
            sessionList[sessionNumber].append(packet)
        return sessionList
    except Exception as e:
        print(e)
