#!/bin/bash
#
# Imput environment vaiables
#
# DB_ROOT_PASSWORD
# DB_PASSWORD
# SERVER_DOMAIN
#


SQLROOTPW=${DB_ROOT_PASSWORD}

cat > /root/.my.cnf <<EOF
[client]
user=root
password=$SQLROOTPW
EOF

chmod 600 /root/.my.cnf

SQLSEAFILEPW=${DB_PASSWORD}

cat > /opt/seafile/.my.cnf <<EOF
[client]
user=seafile
password=$SQLSEAFILEPW
EOF

chmod 600 /opt/seafile/.my.cnf
chown -R seafile.nogroup /opt/seafile/

mysql -e "CREATE DATABASE IF NOT EXISTS \`ccnet-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seafile-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seahub-db\` character set = 'utf8';"
mysql -e "create user 'seafile'@'localhost' identified by '$SQLSEAFILEPW';"
mysql -e "GRANT ALL PRIVILEGES ON \`ccnet-db\`.* to \`seafile\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`seafile-db\`.* to \`seafile\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`seahub-db\`.* to \`seafile\`;"
mysql seahub-db < /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/seahub/sql/mysql.sql


# -------------------------------------------
# Go to /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}
# -------------------------------------------
cd /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/


# -------------------------------------------
# Define Seafile admin credentials.
# -------------------------------------------
SEAFILE_ADMIN=admin@seafile.local
SEAFILE_ADMIN_PW=${ADMIN_PASSWORD}


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
SERVER_NAME=$(hostname -s)
IP_OR_DOMAIN=${SERVER_DOMAIN}
SERVER_PORT=10001
SEAFILE_DATA_DIR=${TOPDIR}/seafile-data
LIBRARY_TEMPLATE_DIR=${SEAFILE_DATA_DIR}/library-template
SRC_DOCS_DIR=${INSTALLPATH}/seafile/docs/
SEAFILE_SERVER_PORT=12001
FILESERVER_PORT=8082
SEAFILESQLPW=$(grep password /opt/seafile/.my.cnf | awk -F'=' {'print $2'})
export SEAFILE_LD_LIBRARY_PATH=${INSTALLPATH}/seafile/lib/:${INSTALLPATH}/seafile/lib64:${LD_LIBRARY_PATH}
DEST_SETTINGS_PY=${TOPDIR}/seahub_settings.py
SEAHUB_SECRET_KEYGEN=${INSTALLPATH}/seahub/tools/secret_key_generator.py
key=$(python "${SEAHUB_SECRET_KEYGEN}")
CCNET_INIT=${INSTALLPATH}/seafile/bin/ccnet-init
SEAF_SERVER_INIT=${INSTALLPATH}/seafile/bin/seaf-server-init
MEDIA_DIR=${INSTALLPATH}/seahub/media
ORIG_AVATAR_DIR=${INSTALLPATH}/seahub/media/avatars
DEST_AVATAR_DIR=${TOPDIR}/seahub-data/avatars
SEAFILE_SERVER_SYMLINK=${TOPDIR}/seafile-server-latest


# -------------------------------------------
# Create ccnet conf
# -------------------------------------------
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH "${CCNET_INIT}" -c "${DEFAULT_CCNET_CONF_DIR}" \
  --name "${SERVER_NAME}" --port "${SERVER_PORT}" --host "${IP_OR_DOMAIN}"

# Fix service url
eval "sed -i 's/^SERVICE_URL.*/SERVICE_URL = https:\/\/${IP_OR_DOMAIN}/' ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf"


# -------------------------------------------
# Create seafile conf
# -------------------------------------------
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH ${SEAF_SERVER_INIT} --seafile-dir "${SEAFILE_DATA_DIR}" \
  --port ${SEAFILE_SERVER_PORT} --fileserver-port ${FILESERVER_PORT}


# -------------------------------------------
# Write seafile.ini
# -------------------------------------------
echo "${SEAFILE_DATA_DIR}" > "${DEFAULT_CCNET_CONF_DIR}/seafile.ini"


# -------------------------------------------
# Configure Seafile WebDAV Server(SeafDAV)
# -------------------------------------------
mkdir -p ${DEFAULT_CONF_DIR}
cat > ${DEFAULT_CONF_DIR}/seafdav.conf <<EOF
[WEBDAV]
enabled = true
port = 8080
fastcgi = true
share_name = /seafdav
EOF


# -------------------------------------------
# generate seahub_settings.py
# -------------------------------------------
echo "SECRET_KEY = \"${key}\"" > "${DEST_SETTINGS_PY}"


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


# Fix permissions
chmod 0600 "$DEST_SETTINGS_PY"
chmod 0700 "$DEFAULT_CCNET_CONF_DIR"
chmod 0700 "$SEAFILE_DATA_DIR"
chmod 0700 "$DEFAULT_CONF_DIR"


# -------------------------------------------
# copy user manuals to library template
# -------------------------------------------
mkdir -p ${LIBRARY_TEMPLATE_DIR}
cp -f ${SRC_DOCS_DIR}/*.doc ${LIBRARY_TEMPLATE_DIR}


# -------------------------------------------
# Configuring ccnet.conf
# -------------------------------------------
cat >> ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf <<EOF

[Database]
ENGINE = mysql
HOST = 127.0.0.1
PORT = 3306
USER = seafile
PASSWD = $SEAFILESQLPW
DB = ccnet-db
CONNECTION_CHARSET = utf8
EOF


# -------------------------------------------
# Configuring seahub_settings.py
# -------------------------------------------
cat >> ${DEST_SETTINGS_PY} <<EOF

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'seahub-db',
        'USER': 'seafile',
        'PASSWORD': '$SEAFILESQLPW',
        'HOST': 'db',
        'PORT': '3306',
        'OPTIONS': {
            'init_command': 'SET storage_engine=INNODB',
        }
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
    'LOCATION': '127.0.0.1:11211',
    }
}

EMAIL_USE_TLS                       = False
EMAIL_HOST                          = 'localhost'
EMAIL_HOST_USER                     = ''
EMAIL_HOST_PASSWORD                 = ''
EMAIL_PORT                          = '25'
DEFAULT_FROM_EMAIL                  = 'seafile@${IP_OR_DOMAIN}'
SERVER_EMAIL                        = 'EMAIL_HOST_USER'
TIME_ZONE                           = 'Europe/Berlin'
SITE_BASE                           = 'https://${IP_OR_DOMAIN}'
SITE_NAME                           = 'Seafile Server'
SITE_TITLE                          = 'Seafile Server'
SITE_ROOT                           = '/'
USE_PDFJS                           = True
ENABLE_SIGNUP                       = False
ACTIVATE_AFTER_REGISTRATION         = False
SEND_EMAIL_ON_ADDING_SYSTEM_MEMBER  = True
SEND_EMAIL_ON_RESETTING_USER_PASSWD = True
CLOUD_MODE                          = False
FILE_PREVIEW_MAX_SIZE               = 30 * 1024 * 1024
SESSION_COOKIE_AGE                  = 60 * 60 * 24 * 7 * 2
SESSION_SAVE_EVERY_REQUEST          = False
SESSION_EXPIRE_AT_BROWSER_CLOSE     = False
FILE_SERVER_ROOT                    = 'https://${IP_OR_DOMAIN}/seafhttp'
EOF


# -------------------------------------------
# Backup check_init_admin.py befor applying changes
# -------------------------------------------
cp ${INSTALLPATH}/check_init_admin.py ${INSTALLPATH}/check_init_admin.py.backup


# -------------------------------------------
# Set admin credentials in check_init_admin.py
# -------------------------------------------
eval "sed -i 's/= ask_admin_email()/= \"${SEAFILE_ADMIN}\"/' ${INSTALLPATH}/check_init_admin.py"
eval "sed -i 's/= ask_admin_password()/= \"${SEAFILE_ADMIN_PW}\"/' ${INSTALLPATH}/check_init_admin.py"


# -------------------------------------------
# Start and stop Seafile eco system. This generates the initial admin user.
# -------------------------------------------
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seafile.sh start
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seahub.sh start
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seahub.sh stop
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seafile.sh stop


# -------------------------------------------
# Restore original check_init_admin.py
# -------------------------------------------
mv ${INSTALLPATH}/check_init_admin.py.backup ${INSTALLPATH}/check_init_admin.py






# -------------------------------------------
# Final report
# -------------------------------------------
cat > ${seafile_dir}/aio_seafile-server.log<<EOF

  Your Seafile server is installed
  -----------------------------------------------------------------

  Server Name:         ${SERVER_NAME}
  Server Address:      https://${IP_OR_DOMAIN}

  Seafile Admin:       ${SEAFILE_ADMIN}
  Admin Password:      ${SEAFILE_ADMIN_PW}

  Seafile Data Dir:    ${SEAFILE_DATA_DIR}

  Seafile DB Credentials:  Check /opt/seafile/.my.cnf
  Root DB Credentials:     Check /root/.my.cnf

  This report is also saved to ${seafile_dir}/aio_seafile-server.log



  Next you should manually complete the following steps
  -----------------------------------------------------------------

  1) seahub_settings.py:  Change IP within FILE_SERVER_ROOT variable to DNS

  2) ccnet.conf:          Change IP within SERVICE_URL variable to DNS

  3) Restart server with: service seafile-server restart

  4) If this server is behind a firewall, you need to ensure that
     tcp port 443 for the NGINX reverse proxy is open. Optionally
     you may also open tcp port 80 which redirects all unencrypted
     http traffic to the encrypted https port.

  5) Seahub tries to send emails via the local server. Install and
     configure Postfix for this to work.




  Optional steps
  -----------------------------------------------------------------

  1) Check seahub_settings.py and customize it to fit your needs. Consult
     http://manual.seafile.com/config/seahub_settings_py.html for possible switches.

  2) Setup NGINX with official SSL certificate.

  3) Secure server with iptables based firewall. For instance: UFW or shorewall

  4) Harden system with port knocking, fail2ban, etc.

  5) Enable unattended installation of security updates. Check
     https://wiki.debian.org/UnattendedUpgrades for details.

  6) Implement a backup routine for your Seafile server.

  7) Update NGINX worker processes to reflect the number of CPU cores.




  Seafile support options
  -----------------------------------------------------------------

  For free community support visit:   https://forum.seafile-server.org
  For paid commercial support visit:  https://seafile.com.de




  About
  -----------------------------------------------------------------

  Please contact alexander.jackson@seafile.com.de
  for bugs or suggestions about this installer. Thank you!

EOF

chmod 600 ${seafile_dir}/aio_seafile-server.log
chown -R seafile.nogroup ${seafile_dir}/aio_seafile-server.log

clear

cat ${seafile_dir}/aio_seafile-server.log
