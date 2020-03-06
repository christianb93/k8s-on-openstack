FROM debian:buster


RUN apt-get update && apt-get -y install net-tools curl
COPY server /usr/local/bin/server

CMD /usr/local/bin/server $(hostname)

