FROM alpine:latest
RUN apk --update add docker python3-dev python3 git ruby-bundler ruby-rdoc ruby-dev gcc ruby-dev make libc-dev openssl-dev libffi-dev
