FROM mhart/alpine-node:0.12.7

RUN adduser -u 127 dovecot -H -D -s /bin/false 137 && adduser -u 128 dovenull -H -D -s /bin/false 138 && \
      apk add --update dovecot dovecot-mysql spamassassin supervisor openssl python make g++ wget ca-certificates bash logrotate && \
      npm install -g Haraka@2.7.0 mkdirp mysql && \
      mkdir -p /tmp/haraka-plugins /default/haraka-plugins /default/dovecot /data && chown mail: /data && \
      sa-update && \
      wget -O /tmp/haraka-plugins.zip https://github.com/mazelab/haraka-plugins/archive/master.zip && \
      unzip /tmp/haraka-plugins.zip -d /tmp && \
      cp -R /tmp/haraka-plugins-master/* /default/haraka-plugins/. && \
      wget -O /default/haraka-plugins/maildir.js https://raw.githubusercontent.com/madeingnecca/haraka-plugins/master/maildir.js && \
      apk del --purge openssl python make g++ wget && \
      rm -r /tmp/* /etc/dovecot/*

ENV HARAKA_DIR /srv/haraka
ENV HARAKA_DEFAULT_PLUGINS /default/haraka-plugins
ENV HARAKA_DEFAULT_CONFIG /usr/lib/node_modules/Haraka/config
ENV DOVECOT_DEFAULT /default/dovecot

ENV DOVECOT_QUERY_USER "SELECT maildir, 8 AS uid, 12 AS gid, concat('*:storage=', quota, 'M') AS quota_rule FROM users WHERE email = '%u'"
ENV DOVECOT_QUERY_PASS "SELECT email AS user, password as password, maildir as userdb_home, 8 AS userdb_uid, 12 AS userdb_gid FROM users WHERE email = '%u'"

ENV HA_QUERY_QUOTA "SELECT user.quota, quota.bytes FROM users as user LEFT JOIN quota as quota ON user.email = quota.username WHERE user.email = '%u'"

ENV MYSQL_PORT_NR "3306"

# copy custom config
COPY dovecot/ $DOVECOT_DEFAULT
COPY haraka $HARAKA_DEFAULT_CONFIG
COPY logrotate.d/ /etc/logrotate.d/

# add starter script
COPY supervisord.ini /etc/supervisor.d/supervisord.ini
COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 25 110 143 993 995

VOLUME ["/srv/haraka/", "/data/", "/etc/dovecot/", "/var/log/"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisor.d/supervisord.ini"]