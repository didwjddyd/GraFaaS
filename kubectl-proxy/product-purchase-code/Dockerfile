FROM dattapubali/of-watchdog:latest-dev-x86_64 as watchdog

FROM node:10.12.0-alpine

COPY --from=watchdog ./fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

RUN apk --no-cache add strace curl

RUN addgroup -S app && adduser -S -g app app && mkdir -p /home/app
USER app

WORKDIR /home/app
COPY . .
RUN npm install

ENV fprocess "node index.js"
ENV mode "http"
ENV http_upstream_url "http://127.0.0.1:3000"
ENV exec_timeout="0"

HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1
CMD ["fwatchdog"]
