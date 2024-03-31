FROM ubuntu:22.04

RUN apt-get update \
 && apt install -y unzip curl git openjdk-18-jre-headless maven

## Install Planetiler
WORKDIR /src

RUN git clone --branch v0.7.0 --recurse-submodules https://github.com/onthegomap/planetiler.git

WORKDIR /src/planetiler

RUN git submodule update --init

RUN unset MAVEN_CONFIG && ./mvnw -DskipTests=true --projects planetiler-dist -am package

ADD planetiler-openmaptiles/src/main/java/org/openmaptiles/layers/*.java planetiler-openmaptiles/src/main/java/org/openmaptiles/layers/

RUN unset MAVEN_CONFIG && ./mvnw -DskipTests=true --projects planetiler-dist -am package

RUN cp /src/planetiler/planetiler-dist/target/planetiler-dist-*-with-deps.jar /opt/planetiler.jar

## Install Tilemaker
WORKDIR /tmp

ADD https://github.com/systemed/tilemaker/releases/download/v2.4.0/tilemaker-ubuntu-22.04.zip .

RUN unzip tilemaker-ubuntu-22.04.zip \
 && mv build/tilemaker /usr/local/bin \
 && chmod +x /usr/local/bin/tilemaker \
 && rm -rf build resources tilemaker-ubuntu-22.04.zip

## Install osmconvert
ADD http://m.m.i24.cc/osmconvert64 /usr/local/bin/osmconvert
RUN chmod +x /usr/local/bin/osmconvert

## Install osmfilter
ADD http://m.m.i24.cc/osmfilter64 /usr/local/bin/osmfilter
RUN chmod +x /usr/local/bin/osmfilter

## Install kubectl
RUN cd /usr/local/bin && curl -LO https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl && chmod +x /usr/local/bin/kubectl

## Install scripts
ADD scripts/*.sh /usr/local/bin

USER 1000

ENV JAVA_TOOL_OPTIONS="-Xmx32g"

ADD tilemaker-configs /tilemaker-configs

CMD /usr/local/bin/update_tiles.sh
