# Dockerfile
FROM dockersec/tcpdump:latest

RUN apt-get update && apt-get install -y \
	inotify-tools\
	python3\
	python3-pip

RUN pip3 install scapy

COPY convert_log.py /tmp/convert_log.py
COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/convert_log.py /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]

