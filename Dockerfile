FROM debian:jessie

ADD start.sh
ADD install.sh

RUN installs.sh

CMD start.sh
