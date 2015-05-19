FROM debian:jessie

RUN apt-get update -y

RUN apt-get install wget -y

ADD nginx.list /etc/apt/sources.list.d/nginx.list
RUN wget -O - http://nginx.org/packages/keys/nginx_signing.key | apt-key add -

RUN apt-get update -y

RUN apt-get install nginx -y

RUN apt-get install sudo mysql-client python-setuptools python-simplejson python-imaging python-mysqldb \
openjdk-7-jre memcached python-memcache pwgen -y

RUN adduser --system --gecos "seafile" seafile --home /opt/seafile
RUN mkdir -p /opt/seafile/haiwen/installed

WORKDIR /opt/seafile/haiwen/
RUN wget https://download.seafile.com.de/seafile-server_latest_x86-64.tar.gz
RUN tar xzf seafile-server_latest_x86-64.tar.gz

RUN rm seafile-server_latest_x86-64.tar.gz

RUN rm /etc/nginx/conf.d/*
ADD seafile.conf /etc/nginx/conf.d/seafile.conf

ADD install.sh ./install.sh
RUN ./install.sh


ADD start.sh ./start.sh
CMD ./start.sh

VOLUME /opt/seafile/haiwen/seafile-data
VOLUME /opt/seafile/haiwen/seahub-data
