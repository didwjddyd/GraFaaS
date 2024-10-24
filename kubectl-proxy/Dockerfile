# 안정적인 OS로 debian 사용
FROM debian:stable-slim

# 패키지 설치 중 상호작용 비활성화
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
    iproute2 \
    strace \
    tcpdump \
    procps \
    net-tools \
    nginx \
    graphviz \
    && apt-get clean

# Python 라이브러리 설치
# Python 라이브러리 설치
RUN pip3 install --break-system-packages scapy \
    networkx \
    matplotlib \ 
    graphviz


# 스크립트 및 파일 복사
COPY entrypoint.sh /tmp/entrypoint.sh
COPY k8s_services_info /tmp/k8s_services_info
COPY tcpdump_gateway.sh /tmp/tcpdump_gateway.sh
COPY create_provenance_graph.py /tmp/create_provenance_graph.py

# 실행 권한 부여
RUN chmod +x /tmp/entrypoint.sh
RUN chmod +x /tmp/tcpdump_gateway.sh
RUN useradd -r nginx


# 시작 스크립트 설정
ENTRYPOINT ["/tmp/entrypoint.sh"]


