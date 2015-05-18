FROM debian:jessie

RUN apt-get update -y
RUN apt-get install wget -y

ADD install.sh ./install.sh
RUN ./install.sh


ADD start.sh ./start.sh
CMD ./start.sh
