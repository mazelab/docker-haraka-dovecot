#!/bin/sh
#
# runtime config
#

if [ -z "$MYSQL_HOST" -o -z "$MYSQL_USER" -o -z "$MYSQL_DATABASE" ]; then
    echo mysql arugments required
    exit 1
fi

# haraka config
hostname -f > /srv/haraka/config/me
hostname -f > /srv/haraka/config/host_list

# haraka plugin configs
/usr/bin/perl -pi -e "s/host=.*$/host=$MYSQL_HOST/" /srv/haraka/config/auth_sql_cryptmd5.ini
/usr/bin/perl -pi -e "s/host=.*$/host=$MYSQL_HOST/" /srv/haraka/config/quota.check.ini
/usr/bin/perl -pi -e "s/host=.*$/host=$MYSQL_HOST/" /srv/haraka/config/aliases_mysql.ini
/usr/bin/perl -pi -e "s/user=.*$/user=$MYSQL_USER/" /srv/haraka/config/auth_sql_cryptmd5.ini
/usr/bin/perl -pi -e "s/user=.*$/user=$MYSQL_USER/" /srv/haraka/config/quota.check.ini
/usr/bin/perl -pi -e "s/user=.*$/user=$MYSQL_USER/" /srv/haraka/config/aliases_mysql.ini
/usr/bin/perl -pi -e "s/password=.*$/password=$MYSQL_PASS/" /srv/haraka/config/auth_sql_cryptmd5.ini
/usr/bin/perl -pi -e "s/password=.*$/password=$MYSQL_PASS/" /srv/haraka/config/quota.check.ini
/usr/bin/perl -pi -e "s/password=.*$/password=$MYSQL_PASS/" /srv/haraka/config/aliases_mysql.ini
/usr/bin/perl -pi -e "s/database=.*$/database=$MYSQL_DATABASE/" /srv/haraka/config/auth_sql_cryptmd5.ini
/usr/bin/perl -pi -e "s/database=.*$/database=$MYSQL_DATABASE/" /srv/haraka/config/quota.check.ini
/usr/bin/perl -pi -e "s/database=.*$/database=$MYSQL_DATABASE/" /srv/haraka/config/aliases_mysql.ini

if [ -f "/tls/tls_cert.pem" -a -f "/tls/tls_key.pem" ]; then
    cp /tls/tls_*.pem /srv/haraka/config/
    echo ssl      = yes >> /etc/dovecot/conf.d/10-ssl.conf
    echo ssl_cert = \</srv/haraka/config/tls_cert.pem >> /etc/dovecot/conf.d/10-ssl.conf
    echo ssl_key  = \</srv/haraka/config/tls_key.pem  >> /etc/dovecot/conf.d/10-ssl.conf
    echo Enabled: SSL\/TLS

    if [ "$SSL_KEY_PASSWORD" ]; then
        echo ssl_key_password = "$SSL_KEY_PASSWORD" >> /etc/dovecot/conf.d/10-ssl.conf
    fi
fi

# dovecot sql && dict sql config
/usr/bin/perl -pi -e "s/^connect=.*?$/connect=host=$MYSQL_HOST dbname=$MYSQL_DATABASE user=$MYSQL_USER password=$MYSQL_PASS" /etc/dovecot/dovecot-sql.conf.ext
/usr/bin/perl -pi -e "s/^connect=.*?$/connect=host=$MYSQL_HOST dbname=$MYSQL_DATABASE user=$MYSQL_USER password=$MYSQL_PASS" /etc/dovecot/dovecot-dict-sql.conf.ext

# start supervisor
exec supervisord
