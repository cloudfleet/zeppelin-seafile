#!/bin/bash
# -------------------------------------------
# NGINX
# -------------------------------------------
cat > /etc/apt/sources.list.d/nginx.list <<EOF
deb http://nginx.org/packages/mainline/debian/ jessie nginx
deb-src http://nginx.org/packages/mainline/debian/ jessie nginx
EOF
wget -O - http://nginx.org/packages/keys/nginx_signing.key | apt-key add -

apt-get update -y
apt-get install nginx -y

rm /etc/nginx/conf.d/*

cat > /etc/nginx/conf.d/seafile.conf <<'EOF'
server {
      listen 80;
      server_name  "";

      location / {
          fastcgi_pass    127.0.0.1:8000;
          fastcgi_param   SCRIPT_FILENAME     $document_root$fastcgi_script_name;
          fastcgi_param   PATH_INFO           $fastcgi_script_name;
          fastcgi_param   SERVER_PROTOCOL     $server_protocol;
          fastcgi_param   QUERY_STRING        $query_string;
          fastcgi_param   REQUEST_METHOD      $request_method;
          fastcgi_param   CONTENT_TYPE        $content_type;
          fastcgi_param   CONTENT_LENGTH      $content_length;
          fastcgi_param   SERVER_ADDR         $server_addr;
          fastcgi_param   SERVER_PORT         $server_port;
          fastcgi_param   SERVER_NAME         $server_name;
          fastcgi_param   HTTPS               on;
          fastcgi_param   HTTP_SCHEME         https;

          access_log      /var/log/nginx/seahub.access.log;
          error_log       /var/log/nginx/seahub.error.log;
      }
      location /seafhttp {
          rewrite ^/seafhttp(.*)$ $1 break;
          proxy_pass http://127.0.0.1:8082;
          client_max_body_size 0;
          proxy_connect_timeout  36000s;
          proxy_read_timeout  36000s;
      }
      location /media {
          root /opt/seafile/haiwen/seafile-server-latest/seahub;
      }
     location /seafdav {
        fastcgi_pass    127.0.0.1:8080;
        fastcgi_param   SCRIPT_FILENAME     $document_root$fastcgi_script_name;
        fastcgi_param   PATH_INFO           $fastcgi_script_name;
        fastcgi_param   SERVER_PROTOCOL     $server_protocol;
        fastcgi_param   QUERY_STRING        $query_string;
        fastcgi_param   REQUEST_METHOD      $request_method;
        fastcgi_param   CONTENT_TYPE        $content_type;
        fastcgi_param   CONTENT_LENGTH      $content_length;
        fastcgi_param   SERVER_ADDR         $server_addr;
        fastcgi_param   SERVER_PORT         $server_port;
        fastcgi_param   SERVER_NAME         $server_name;
        fastcgi_param   HTTPS               on;

        client_max_body_size 0;

        access_log      /var/log/nginx/seafdav.access.log;
        error_log       /var/log/nginx/seafdav.error.log;
    }
  }
EOF

# -------------------------------------------
# Additional requirements
# -------------------------------------------
apt-get install sudo python-setuptools python-simplejson python-imaging python-mysqldb \
openjdk-7-jre memcached python-memcache pwgen curl -y


# -------------------------------------------
# Seafile
# -------------------------------------------
adduser --system --gecos "seafile" seafile --home /opt/seafile
mkdir -p /opt/seafile/haiwen/installed
cd /opt/seafile/haiwen/
curl -OL https://download.seafile.com.de/seafile-server_latest_x86-64.tar.gz
tar xzf seafile-server_latest_x86-64.tar.gz

SEAFILE_VERSION=$(basename /opt/seafile/haiwen/seafile-server-* | awk -F'-' ' { print $3  }')

mv seafile-server_latest_x86-64.tar.gz installed/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz




# -------------------------------------------
# Go to /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}
# -------------------------------------------
cd /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/


# -------------------------------------------
# Define Seafile admin credentials.
# -------------------------------------------
SEAFILE_ADMIN=admin@seafile.local
SEAFILE_ADMIN_PW=$(pwgen)


# -------------------------------------------
# Vars - Don't touch these unless you really know what you are doing!
# -------------------------------------------
SCRIPT=$(readlink -f "$0")
#INSTALLPATH=$(dirname "${SCRIPT}")
INSTALLPATH=/opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/


TOPDIR=$(dirname "${INSTALLPATH}")
DEFAULT_CCNET_CONF_DIR=${TOPDIR}/ccnet
DEFAULT_SEAFILE_DATA_DIR=${TOPDIR}/seafile-data
DEFAULT_SEAHUB_DB=${TOPDIR}/seahub.db
DEFAULT_CONF_DIR=${TOPDIR}/conf
SERVER_PORT=10001
SEAFILE_DATA_DIR=${TOPDIR}/seafile-data
LIBRARY_TEMPLATE_DIR=${SEAFILE_DATA_DIR}/library-template
SRC_DOCS_DIR=${INSTALLPATH}/seafile/docs/
SEAFILE_SERVER_PORT=12001
FILESERVER_PORT=8082
export SEAFILE_LD_LIBRARY_PATH=${INSTALLPATH}/seafile/lib/:${INSTALLPATH}/seafile/lib64:${LD_LIBRARY_PATH}
DEST_SETTINGS_PY=${TOPDIR}/seahub_settings.py
SEAHUB_SECRET_KEYGEN=${INSTALLPATH}/seahub/tools/secret_key_generator.py
CCNET_INIT=${INSTALLPATH}/seafile/bin/ccnet-init
SEAF_SERVER_INIT=${INSTALLPATH}/seafile/bin/seaf-server-init
MEDIA_DIR=${INSTALLPATH}/seahub/media
ORIG_AVATAR_DIR=${INSTALLPATH}/seahub/media/avatars
DEST_AVATAR_DIR=${TOPDIR}/seahub-data/avatars
SEAFILE_SERVER_SYMLINK=${TOPDIR}/seafile-server-latest

# -------------------------------------------
# prepare avatar directory
# -------------------------------------------
mkdir -p "${TOPDIR}/seahub-data"
mv "${ORIG_AVATAR_DIR}" "${DEST_AVATAR_DIR}"
ln -s ../../../seahub-data/avatars ${MEDIA_DIR}


# -------------------------------------------
# create logs directory
# -------------------------------------------
mkdir -p "${TOPDIR}/logs"


# -------------------------------------------
# Create symlink for current server version
# -------------------------------------------
ln -s $(basename ${INSTALLPATH}) ${SEAFILE_SERVER_SYMLINK}


# -------------------------------------------
# copy user manuals to library template
# -------------------------------------------
mkdir -p ${LIBRARY_TEMPLATE_DIR}
cp -f ${SRC_DOCS_DIR}/*.doc ${LIBRARY_TEMPLATE_DIR}


# -------------------------------------------
# Fix permissions
# -------------------------------------------
chown seafile.nogroup -R /opt/seafile/
