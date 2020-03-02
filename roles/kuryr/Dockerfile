FROM python:3.6.10-buster

#
# Install Git 
#
RUN apt-get -y update && apt-get -y install git
#
# Get sourcecode
#
RUN git clone https://github.com/openstack/kuryr-kubernetes.git/ -b stable/stein --depth=1
#
# Run install 
#
RUN pip3 install -e kuryr-kubernetes

