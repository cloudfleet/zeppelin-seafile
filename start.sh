#!/bin/bash
#
# Imput environment vaiables
#
# DB_ROOT_PASSWORD
# DB_PASSWORD
# SERVER_DOMAIN
#

SEAFILE_VERSION=$(basename /opt/seafile/haiwen/seafile-server-* | awk -F'-' ' { print $3  }')
SQLROOTPW=${DB_ROOT_PASSWORD}

cat > /root/.my.cnf <<EOF
[client]
host=db
user=root
password=$SQLROOTPW
EOF

chmod 600 /root/.my.cnf

SQLSEAFILEPW=${DB_PASSWORD}

cat > /opt/seafile/.my.cnf <<EOF
[client]
host=db
user=seafile
password=$SQLSEAFILEPW
EOF

chmod 600 /opt/seafile/.my.cnf
chown -R seafile.nogroup /opt/seafile/

echo "Waiting for database ..."
sleep 3

echo "Setting up database if necessary ..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`ccnet-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seafile-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seahub-db\` character set = 'utf8';"
mysql -e "GRANT ALL PRIVILEGES ON \`ccnet-db\`.* to \`seafile\` identified by '$SQLSEAFILEPW';"
mysql -e "GRANT ALL PRIVILEGES ON \`seafile-db\`.* to \`seafile\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`seahub-db\`.* to \`seafile\`;"
mysql seahub-db < /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/seahub/sql/mysql.sql


echo "Changing to /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/"
cd /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/

echo "Setting up variables ..."
SEAFILE_ADMIN=admin@seafile.local
SEAFILE_ADMIN_PW=${ADMIN_PASSWORD}


# -------------------------------------------
# Vars - Don't touch these unless you really know what you are doing!
# -------------------------------------------
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
SEAFILESQLPW=$SQLSEAFILEPW
DEST_SETTINGS_PY=${TOPDIR}/seahub_settings.py
SEAHUB_SECRET_KEYGEN=${INSTALLPATH}/seahub/tools/secret_key_generator.py
key=$(python "${SEAHUB_SECRET_KEYGEN}")
CCNET_INIT=${INSTALLPATH}/seafile/bin/ccnet-init
SEAF_SERVER_INIT=${INSTALLPATH}/seafile/bin/seaf-server-init
MEDIA_DIR=${INSTALLPATH}/seahub/media
ORIG_AVATAR_DIR=${INSTALLPATH}/seahub/media/avatars
DEST_AVATAR_DIR=${TOPDIR}/seahub-data/avatars
SEAFILE_SERVER_SYMLINK=${TOPDIR}/seafile-server-latest



export SEAFILE_LD_LIBRARY_PATH=${INSTALLPATH}/seafile/lib/:${INSTALLPATH}/seafile/lib64:${LD_LIBRARY_PATH}

echo "Creating ccnet conf ..."
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH "${CCNET_INIT}" -c "${DEFAULT_CCNET_CONF_DIR}" \
  --name "${SERVER_NAME}" --port "${SERVER_PORT}" --host "${IP_OR_DOMAIN}"

# Fix service url
eval "sed -i 's/^SERVICE_URL.*/SERVICE_URL = https:\/\/${IP_OR_DOMAIN}/' ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf"


echo "Creating seafile conf ..."
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH ${SEAF_SERVER_INIT} --seafile-dir "${SEAFILE_DATA_DIR}" \
  --port ${SEAFILE_SERVER_PORT} --fileserver-port ${FILESERVER_PORT}


echo "Creating seafile.ini ..."

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
echo "generate seahub_settings.py"
# -------------------------------------------
echo "SECRET_KEY = \"${key}\"" > "${DEST_SETTINGS_PY}"


# -------------------------------------------
echo "prepare avatar directory"
# -------------------------------------------
mkdir -p "${TOPDIR}/seahub-data"
mv "${ORIG_AVATAR_DIR}" "${DEST_AVATAR_DIR}"
ln -s ../../../seahub-data/avatars ${MEDIA_DIR}


# -------------------------------------------
echo "create logs directory"
# -------------------------------------------
mkdir -p "${TOPDIR}/logs"


# -------------------------------------------
echo "Create symlink for current server version"
# -------------------------------------------
ln -s $(basename ${INSTALLPATH}) ${SEAFILE_SERVER_SYMLINK}


echo "Fix permissions"
chmod 0600 "$DEST_SETTINGS_PY"
chmod 0700 "$DEFAULT_CCNET_CONF_DIR"
chmod 0700 "$SEAFILE_DATA_DIR"
chmod 0700 "$DEFAULT_CONF_DIR"


# -------------------------------------------
echo "copy user manuals to library template"
# -------------------------------------------
mkdir -p ${LIBRARY_TEMPLATE_DIR}
cp -f ${SRC_DOCS_DIR}/*.doc ${LIBRARY_TEMPLATE_DIR}


# -------------------------------------------
echo "Configuring ccnet.conf"
# -------------------------------------------
cat >> ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf <<EOF

[Database]
ENGINE = mysql
HOST = db
PORT = 3306
USER = seafile
PASSWD = $SEAFILESQLPW
DB = ccnet-db
CONNECTION_CHARSET = utf8
EOF


# -------------------------------------------
echo "Configuring seahub_settings.py"
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
echo "Backup check_init_admin.py befor applying changes"
# -------------------------------------------
cp ${INSTALLPATH}/check_init_admin.py ${INSTALLPATH}/check_init_admin.py.backup


# -------------------------------------------
echo "Set admin credentials in check_init_admin.py"
# -------------------------------------------
eval "sed -i 's/= ask_admin_email()/= \"${SEAFILE_ADMIN}\"/' ${INSTALLPATH}/check_init_admin.py"
eval "sed -i 's/= ask_admin_password()/= \"${SEAFILE_ADMIN_PW}\"/' ${INSTALLPATH}/check_init_admin.py"

echo "${SEAFILE_ADMIN} - ${SEAFILE_ADMIN_PW}"

# -------------------------------------------
echo "Start and stop Seafile eco system. This generates the initial admin user."
# -------------------------------------------
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seafile.sh start
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seahub.sh start
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seahub.sh stop
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seafile.sh stop


# -------------------------------------------
echo "Restore original check_init_admin.py"
# -------------------------------------------
mv ${INSTALLPATH}/check_init_admin.py.backup ${INSTALLPATH}/check_init_admin.py

echo "Starting seahub"
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seafile.sh start
${TOPDIR}/seafile-server-${SEAFILE_VERSION}/seahub.sh start-fastcgi 8000
service nginx start

tail -f `ls ${TOPDIR}/logs/*.log` `ls /var/log/nginx/*.log`
