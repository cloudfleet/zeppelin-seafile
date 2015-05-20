# What is seafile

TBD

# How To Use This Container

## Start A Seafile Server

The easiest way to start a seafile server is with docker compose, [the example file](https://github.com/cloudfleet/zeppelin-seafile/blob/master/docker-compose.yml) shows the basic variables that need to be configured and the link to a mysql instance.

Without docker compose the task is almost as easy.

First we have to start a mysql container 

```bash
docker run --name seafile-mysql \
  -e MYSQL_ROOT_PASSWORD=mysecretpassword \
  --volume=/srv/docker/seafile/mysql:/var/lib/mysql \
  -d \
  mysql 
```

Then we can start our seafile container and link to it

```bash
docker run --name seafile \
  -e DB_ROOT_PASSWORD=mysecretpassword \
  -e DB_PASSWORD=seafile_password \
  -e SERVER_DOMAIN=yourdomain.example.com \
  -e ADMIN_PASSWORD: test123 \
  --link=seafile-mysql:db \
  --volume=/srv/docker/seafile/seafile-data:/opt/seafile/haiwen/seafile-data \
  --volume=/srv/docker/seafile/seahub-data:/opt/seafile/haiwen/seahub-data \
  -d \
  cloudfleet/zeppelin-seafile
```

## Environment Variables

TBD


