#!/bin/bash

set -e

function initHaraka() {
  # install haraka config
  if [ ! -d "$HARAKA_DIR/config" ] ; then
    echo "installing haraka config..."
    cp -R $HARAKA_DEFAULT_CONFIG $HARAKA_DIR/config
  fi

  # install haraka plugins
  if [ ! -d "$HARAKA_DIR/plugins" ] ; then
    echo "installing haraka plugins..."

    # add plugin files
    mkdir -p $HARAKA_DIR/plugins/auth
    cp $HARAKA_DEFAULT_PLUGINS/plugins/*.js $HARAKA_DIR/plugins/.

    # add plugin config
    cp $HARAKA_DEFAULT_PLUGINS/config/* $HARAKA_DIR/config/.

    if [ -f "$HARAKA_DIR/plugins/auth_mysql_cryptmd5.js" ]; then
      mv $HARAKA_DIR/plugins/auth_mysql_cryptmd5.js $HARAKA_DIR/plugins/auth/.
    fi
    if [ -f "$HARAKA_DIR/plugins/cryptmd5.js" ]; then
      mv $HARAKA_DIR/plugins/cryptmd5.js $HARAKA_DIR/plugins/auth/.
    fi
  fi

  # create haraka queue folder
  if [ ! -d "$HARAKA_DIR/queue" ] ; then
    mkdir $HARAKA_DIR/queue
  fi

  hostname -f > $HARAKA_DIR/config/me
  hostname -f > $HARAKA_DIR/config/host_list

  # setup haraka mysql stuff
  if [ ! -z "$MYSQL_HOST" ]; then
    sed -i "s/^host=.*/host=$MYSQL_HOST/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$MYSQL_USER" ]; then
    sed -i "s/^user=.*/user=$MYSQL_USER/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$MYSQL_PASS" ]; then
    sed -i "s/^password=.*/password=$MYSQL_PASS/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$MYSQL_DATABASE" ]; then
    sed -i "s/^database=.*/database=$MYSQL_DATABASE/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$MYSQL_PORT_NR" ]; then
    sed -i "s/^port=.*/port=$MYSQL_PORT_NR/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$MYSQL_CHARSET" ]; then
    sed -i "s/^char_set=.*/char_set=$MYSQL_CHARSET/g" $HARAKA_DIR/config/mysql_provider.ini
  fi
  if [ ! -z "$HA_QUERY_ALIASES" ]; then
    sed -i "s/^query=.*/query=$HA_QUERY_ALIASES/g" $HARAKA_DIR/config/aliases_mysql.ini
  fi
  if [ ! -z "$HA_QUERY_AUTH" ]; then
    sed -i "s/^query=.*/query=$HA_QUERY_AUTH/g" $HARAKA_DIR/config/auth_mysql_cryptmd5.ini
  fi
  if [ ! -z "$HA_QUERY_QUOTA" ]; then
    sed -i "s/^query=.*/query=$HA_QUERY_QUOTA/g" $HARAKA_DIR/config/quota_mysql.ini
  fi
  if [ ! -z "$HA_QUERY_RCPT_TO" ]; then
    sed -i "s/^query=.*/query=$HA_QUERY_RCPT_TO/g" $HARAKA_DIR/config/rcpt_to.mysql.ini
  fi
}

function initDovecot() {
  if [ -z "$(ls -A /etc/dovecot)" ]; then
    echo "installing dovecot config..."
    cp -R $DOVECOT_DEFAULT/* /etc/dovecot/.
  fi

  if [ ! "`cat /etc/dovecot/dovecot-sql.conf.ext | grep '^connect'`" ]; then
    echo "connect = host=$MYSQL_HOST port=$MYSQL_PORT_NR dbname=$MYSQL_DATABASE user=$MYSQL_USER password=$MYSQL_PASS" >> /etc/dovecot/dovecot-sql.conf.ext
  fi
  if [ ! "`cat /etc/dovecot/dovecot-dict-sql.conf.ext | grep '^connect'`" ]; then
    echo "connect = host=$MYSQL_HOST port=$MYSQL_PORT_NR dbname=$MYSQL_DATABASE user=$MYSQL_USER password=$MYSQL_PASS" >> /etc/dovecot/dovecot-dict-sql.conf.ext
  fi

  if [ "$DOVECOT_QUERY_USER" -a ! "`cat /etc/dovecot/dovecot-sql.conf.ext | grep '^user_query ='`" ]; then
    echo "user_query = $DOVECOT_QUERY_USER" >> /etc/dovecot/dovecot-sql.conf.ext
  fi
  if [ "$DOVECOT_QUERY_PASS" -a ! "`cat /etc/dovecot/dovecot-sql.conf.ext | grep '^password_query ='`" ]; then
    echo "password_query = $DOVECOT_QUERY_PASS" >> /etc/dovecot/dovecot-sql.conf.ext
  fi
}

function initTLS() {
  if [ ! -f "$HARAKA_DIR/config/tls_cert.pem" ]; then
    echo "Installing self signed ssl cert"
    openssl req -x509 -nodes -days 2190 -newkey rsa:2048 \
            -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
            -keyout $HARAKA_DIR/config/tls_key.pem -out $HARAKA_DIR/config/tls_cert.pem
  fi

  if [ ! -s "/etc/dovecot/conf.d/10-ssl.conf" ]; then
    echo "ssl      = yes" >> /etc/dovecot/conf.d/10-ssl.conf
    echo "ssl_cert = <$HARAKA_DIR/config/tls_cert.pem" >> /etc/dovecot/conf.d/10-ssl.conf
    echo "ssl_key  = <$HARAKA_DIR/config/tls_key.pem"  >> /etc/dovecot/conf.d/10-ssl.conf
  fi
}

function fixPermissions() {
  #secure cert permissions
  if [ -f "$HARAKA_DIR/config/tls_cert.pem" ]; then
    chmod 444 $HARAKA_DIR/config/tls_cert.pem
  fi
  if [ -f "$HARAKA_DIR/config/tls_key.pem" ]; then
    chmod 400 $HARAKA_DIR/config/tls_key.pem
  fi

  # map permissions to the user who mounted /data
  DATA_UID=`ls -ldn "/data" | awk '{print $3}'`
  MAPPED_USER=`getent passwd $DATA_UID | awk -F':' '{print $1}'`
  MAIL_USER="mail"

  if [ -z "$MAPPED_USER" ]; then
    echo "Map mail user to $DATA_UID"
    usermod -u $DATA_UID $MAIL_USER
  elif [ "$MAPPED_USER" != "$MAIL_USER" ]; then
    echo "system users ($MAPPED_USER) except mail should not own data. Changing ownership of /data/..."
    chown -R mail: /data
  fi

  # set queue ownership
  chown -R mail: $HARAKA_DIR/queue
}

# runtime configuration in order to support mounts
if [[ "$*" == supervisord* ]]; then
  initHaraka
  initDovecot
  initTLS
  fixPermissions
fi

exec "$@"