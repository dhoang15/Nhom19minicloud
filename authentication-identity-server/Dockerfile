FROM alpine:3.22
RUN apk add --no-cache curl jq
COPY init-users.sh /usr/local/bin/init-users
ENTRYPOINT ["/bin/sh", "/usr/local/bin/init-users"]
