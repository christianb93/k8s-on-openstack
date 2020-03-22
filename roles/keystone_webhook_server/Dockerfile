FROM golang:1.14-buster 

RUN git clone https://github.com/kubernetes/cloud-provider-openstack 

WORKDIR cloud-provider-openstack 

RUN git checkout v1.17.0 && go get ./...

 

