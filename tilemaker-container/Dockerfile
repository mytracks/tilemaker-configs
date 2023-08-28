FROM ubuntu:22.04

RUN apt-get update \
 && apt install -y unzip

WORKDIR /tmp

ADD https://github.com/systemed/tilemaker/releases/download/v2.4.0/tilemaker-ubuntu-22.04.zip .

RUN unzip tilemaker-ubuntu-22.04.zip \
 && mv build/tilemaker /usr/local/bin \
 && chmod +x /usr/local/bin/tilemaker \
 && rm -rf build resources tilemaker-ubuntu-22.04.zip

ADD http://m.m.i24.cc/osmconvert64 /usr/local/bin/osmconvert
RUN chmod +x /usr/local/bin/osmconvert
