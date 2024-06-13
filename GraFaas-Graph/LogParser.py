import SessionBlock

def LogToSessions(logFileName:str) -> list:
    try:
        tcpdumpLog = __GetTcpdumpLog(logFileName)
        packetList, arpList = __ParseTcpdumpLog(tcpdumpLog)

        # for arp in arpList:
        #     print({
        #         # 'psrc': arp.psrc,
        #         'pdst': arp.pdst,
        #         'hwdst':arp.hwdst
        #     })

        sessionList = __CreateSessionList(packetList, arpList)
        return sessionList
    except Exception as e:
        print('LogToSessions')
        print(e)

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
        print('__GetTcpdumpLog')
        print(e)

def __ParseTcpdumpLog(tcpdumpLog:list) -> tuple[list, list[SessionBlock.ARPBlock]]:
    # tcpdumplog parsing
    # TCP의 src: 요청을 보낸 주소
    # ARP의 src: 요청을 받은 주소
    packetList = []
    arpList = []
    try:
        parsedTcpDumpLog = tcpdumpLog.split('\n')
        rawNumber = 0
        for line in parsedTcpDumpLog:
            if line == 'end':
                break
            parsedLine = line.split(' ')
            hasRaw = True if parsedLine[-1] == 'Raw' else False
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
                    'hasRaw':hasRaw,
                    'rawNumber':rawNumber if hasRaw else -1
                }
                #print(block)
                packetList.append(SessionBlock.TCPPacket(block))
            elif parsedLine[2] == 'ARP':
                print(parsedLine)
                #print('ARP')
                print(len(arpList))
                op = 0 if parsedLine[3] == 'who'  else 1 # 0: who has | 1: is at
                if op == 0 and __FindARPBlock(arpList, parsedLine[-3]) == None:  # who has
                    block = {
                        'type':'ARP',
                        'hwsrc':None,
                        # 'psrc':parsedLine[-1],
                        'hwdst':None,
                        'pdst':parsedLine[-3]
                    }
                    #print(block)
                    arpList.append(SessionBlock.ARPBlock(block))
                elif op == 1: # is at
                    psrc = parsedLine[-1]
                    whoHas = __FindARPBlock(arpList, psrc)
                    hwdst = parsedLine[-3]
                    if whoHas.hwdst == None:
                        whoHas.hwdst = hwdst
            else:
                #print('None')
                block = {
                    'type': parsedLine[-3],
                    'proto': None,
                    'src': parsedLine[0],
                    'sport':None,
                    'dst': parsedLine[2],
                    'dport':None,
                    'flag':None,
                    'hasRaw':hasRaw,
                    'rawNumber':rawNumber if hasRaw else -1
                }
                #print(block)
                packetList.append(SessionBlock.TCPPacket(block))
        return packetList, arpList
    except Exception as e:
        print('__ParseTcpDumpLog')
        print(e)

def __FindARPBlock(arpList:list, psrc:str) -> SessionBlock.ARPBlock:
    result = None
    try:
        if len(arpList) != 0:
            for arpBlock in arpList:
                if arpBlock.pdst == psrc:# and arpBlock.hwdst == None:
                    result = arpBlock
        return result
    except Exception as e:
        print('__FindARPBlock')
        print(e)

def __CreateSessionList(packetList:list, arpList:list) -> list:
    # make session list
    # Prototype: session Class로 대체 예정
    sessionList = [] # Prototype | element: [((), ()), TCPPacket]
    try:
        for packet in packetList:
            # create session
            sessionNumber = 0
            # address1 = f'{packet.src()}:{packet.sport()}' if packet.sport() != None else packet.src()
            # addressARP1 = __FindARPBlock(arpList, packet.src())
            # hwaddress1 = addressARP1.hwdst if addressARP1 != None else None
            # address2 = f'{packet.dst()}:{packet.dport()}' if packet.dport() != None else packet.dst()
            # addressARP2 = __FindARPBlock(arpList, packet.dst())
            # hwaddress2 = addressARP2.hwdst if addressARP2 != None else None

            address1 = packet.src()
            addressARP1 = __FindARPBlock(arpList, address1)
            hwaddress1 = addressARP1.hwdst if addressARP1 != None else None
            address2 = packet.dst()
            addressARP2 = __FindARPBlock(arpList, address2)
            hwaddress2 = addressARP2.hwdst if addressARP2 != None else None

            if len(sessionList) == 0:
                addressTuple1 = (address1, hwaddress1)
                addressTuple2 = (address2, hwaddress2)
                sessionList.append([(addressTuple1, addressTuple2)])
            else:
                for i in range(0, len(sessionList)):
                    session = sessionList[i][0]
                    # if (address1, hwaddress1) in session and (address2, hwaddress2) in session:
                    #     sessionNumber = i
                    #     break
                    if address1 in session and address2 in session:
                        sessionNumber = i
                        break
                else:
                    addressTuple1 = (address1, hwaddress1)
                    addressTuple2 = (address2, hwaddress2)
                    sessionList.append([(addressTuple1, addressTuple2)])
                    sessionNumber = len(sessionList) - 1
            sessionList[sessionNumber].append(packet)

            # for session in sessionList:
            #     print(session[0])
        return sessionList
    except Exception as e:
        print('__CreateSessionList')
        print(e)
