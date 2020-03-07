FROM debian:buster

#
# Install needed packages
#
RUN apt-get update && apt-get -y install net-tools curl 


# 
# Install simple server
# 
COPY server /usr/local/bin/server

#
# Install kubectl
#
RUN apt-get -y install wget && wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl && cp kubectl /usr/local/bin && chmod 700 /usr/local/bin/kubectl


CMD /usr/local/bin/server $(hostname)

