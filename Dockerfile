FROM mhart/alpine-node:0.12.7

RUN apk-install openssl dovecot dovecot-mysql python spamassassin supervisor make g++ wget

# install haraka
RUN npm install -g Haraka mkdirp mysql
RUN mkdir /srv && haraka -i /srv/haraka && mkdir /srv/haraka/queue

# haraka config
ADD haraka/plugins /srv/haraka/plugins
ADD haraka/config /srv/haraka/config

# dovecot config
ADD dovecot/ /etc/dovecot/

# spamassassin config
RUN sa-update

# maildirs config
RUN mkdir /data/ && chown mail:mail -R /data/ /srv/haraka/queue/

# add starter script
ADD supervisord.ini /etc/supervisor.d/supervisord.ini
ADD run.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

EXPOSE 25 110 143

VOLUME /data/

CMD ["/usr/local/bin/run"]