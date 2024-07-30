# Dockerfile
FROM dockersec/tcpdump:latest

ENV DEBIAN_FRONTEND=noninteractive



# 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    inotify-tools \
    python3 \
    python3-pip \
    xxd \
    bpfcc-tools \
    bpftrace \
    linux-headers-generic \
    && apt-get clean

RUN pip3 install scapy \
    networkx \
    matplotlib

COPY create_graph.py /tmp/create_graph.py
COPY entrypoint.sh /tmp/entrypoint.sh
COPY container_info.txt /tmp/container_info.txt

RUN chmod +x /tmp/create_graph.py 
RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]



