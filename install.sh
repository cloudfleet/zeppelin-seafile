SEAFILE_VERSION=$(basename /opt/seafile/haiwen/seafile-server-* | awk -F'-' ' { print $3  }')

cd /opt/seafile/haiwen/seafile-server-${SEAFILE_VERSION}/


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
