Mailserver with Haraka, Dovecot and MySQL
----------
Haraka SMTP Email Server with Dovecot and MySQL backend. 
This container includes services for SMTP, POP3 and IMAP.

**Features:**

- Spam detection
- Quota
- TLS
- Forwarder (alias) support

## Requirements

- MySQL Server

## Installation

Automated builds are available on [dockerhub](https://hub.docker.com/r/mazelab/haraka-dovecot/):

    docker pull mazelab/haraka-dovecot:latest
    
Or trigger a build locally:

    docker build -t mazelab/haraka-dovecot github.com/mazelab/docker-haraka-dovecot


## Quick Start

This container uses an external MySQL service as the backend. The MySQL queries can be configured through environment variables. See Mysql and environment variables for more explanation on that part.

Start server with external mysql:

    docker run -d -p 25:25 -p 110:110 -p 143:143 -e HOSTNAME=mail.dev -e MYSQL_HOST=mysql.dev -e MYSQL_USER=root -e MYSQL_PASS=my-secret-pw -e MYSQL_DATABASE=mail-sample --name mail-sample mazelab/haraka-dovecot
    
Show logs:

    docker exec -it mail-sample sh -c 'tail -f /var/log/*.log'


## Environment variables

For docker container hostname use -e mail.dev or -h mail.dev.

- `HOSTNAME`: Server hostname for the container
- `MYSQL_HOST`: Server address of the MySQL server
- `MYSQL_PORT_NR`: Server port of the MySQL server (default: 3306)
- `MYSQL_USER`: Username for mysql access
- `MYSQL_PASS`: Password for mysql access
- `MYSQL_DATABASE`: Database name to use
- `MYSQL_CHARSET`: MySQL charset on connections (default: UTF-8)

Haraka:

A detailed documentation for the plugins can be found [here](https://github.com/mazelab/haraka-plugins).

- `HA_QUERY_AUTH`: Haraka mysql query to to authorize a login request
- `HA_QUERY_QUOTA`: Haraka mysql query to fetch quota data
- `HA_QUERY_RCPT_TO`: Haraka mysql query to check if email target exists in database
- `HA_QUERY_ALIASES`: Haraka mysql query to fetch alias data of the target email

Dovecot:

- `DOVECOT_QUERY_USER`: Dovecot mysql query to fetch user data
- `DOVECOT_QUERY_PASS`: Dovecot mysql query to fetch user password


## Advanced examples

Server with mounted mail content:

    docker run -p 25:25 -p 110:110 -p 143:143 -v /my/mailContent/:/data/ mazelab/haraka-dovecot

Server with mounted logs:

    docker run -p 25:25 -p 110:110 -p 143:143 -v /my/logs/:/var/logs mazelab/haraka-dovecot

Server with custom certificates:

    docker run -p 25:25 -p 110:110 -p 143:143 -v /my/tls_key.pem:/default/haraka-plugins/config/tls_key.pem -v /my/tls_cert.pem:/default/haraka-plugins/config/tls_cert.pem mazelab/haraka-dovecot
    
Server with custom Haraka:

    docker run -p 25:25 -p 110:110 -p 143:143 -v /my/haraka/:/srv/haraka mazelab/haraka-dovecot

Server with custom dovecot:

    docker run -p 25:25 -p 110:110 -p 143:143 -v /my/dovecot/:/etc/dovecot mazelab/haraka-dovecot


## Other

### Quota

Dovecot keeps track of the current quota usage. MySQL is used to store the quota.
The MySQL definition is more static and only configurable in /etc/dovecot/dovecot-dict-sql.conf.ext. 
It is not necessary to edit this table. It is solely managed by dovecot (except table creation). Haraka only reads the used quota. 
So if dovecot-dict-sql.conf.ext was changed you probably have to change the HA_QUERY_QUOTA env.

### SpamAssassin

E-mail spam detection based on content-matching rules. Flags detected emails with a *** Spam *** addition in the subject.

### SSL

The container creates a new unsigned certificate when no certificate is available.

#### Certificate Locations

Default:

- /default/haraka-plugins/config/tls_key.pem 
- /default/haraka-plugins/config/tls_cert.pem

When /srv/haraka is mounted then:

- /srv/haraka/config/tls_cert.pem
- /srv/haraka/config/tls_key.pem

### Logging

Every service creates logs in /var/log.


## Example MySQL setup

If you want a quick database example then do the following:

Create a mysql container

    docker run -d --name mysql-mail -e MYSQL_ROOT_PASSWORD=my-secret-pw -e MYSQL_DATABASE=mail-sample mysql
    
Start email server with link

    docker run --link mysql-mail:mysql -d -p 25:25 -p 110:110 -p 143:143 -e HOSTNAME=mail.dev -e MYSQL_HOST=mysql -e MYSQL_USER=root -e MYSQL_PASS=my-secret-pw -e MYSQL_DATABASE=mail-sample --name mail-sample  mazelab/haraka-dovecot

Wait a few seconds then execute ...

    docker exec -it mysql-mail mysql -u root -pmy-secret-pw mail-sample

... and copy/paste this dump
    
    CREATE TABLE IF NOT EXISTS `users` (
      `email` varchar(255) NOT NULL,
      `password` varchar(255) NOT NULL DEFAULT '',
      `maildir` varchar(255) DEFAULT NULL,
      `quota` varchar(255) DEFAULT NULL,
      PRIMARY KEY (`email`)
    ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;
    
    CREATE TABLE IF NOT EXISTS `aliases` (
      `email` varchar(255) NOT NULL,
      `action` varchar(255) DEFAULT NULL,
      `config` varchar(255) DEFAULT NULL,
      PRIMARY KEY (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    
    CREATE TABLE IF NOT EXISTS quota (
      username varchar(100) not null,
      bytes bigint not null default 0,
      messages integer not null default 0,
      primary key (`username`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    
Hit enter and type exit to close the terminal.

### Adding Users

Generating a password string:

    docker exec mail-sample doveadm pw -s MD5-CRYPT -p thepassword
    {MD5-CRYPT}$1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/ 
    # -> password string is $1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/

Go into mysql again:

    docker exec -it mysql-mail mysql -u root -pmy-secret-pw mail-sample
    
Use query to add new users:
    
    // email noquota@test.dev, pw: apassword
    INSERT INTO `users` (email, password, maildir) VALUES('noquota@test.dev', '$1$DPbCiW2l$NtRkAMOgIzd3l0Q2TUifW/', '/data/test.dev/noquota');
    
    // email 100quota@test.dev, pw: rndpass, 100 MB quota
    INSERT INTO `users` (email, password, maildir, quota) VALUES('100quota@test.dev','$1$U1ziNWes$.sxQoQ/fxeGRBV5eKFqzl/', '/data/test.dev/100quota','100');
    
    // email 1quota@test.dev, pw: noword, 1 MB quota
    INSERT INTO `users` (email, password, maildir, quota) VALUES('1quota@test.dev','$1$p0RKuvbR$/MRQDr6u40jxMG7A1cAcI.', '/data/test.dev/1quota', '1');

### Adding Forwarder

    INSERT INTO `aliases` (email, action, config) VALUES('forward@test.dev','alias', 'noquota@test.dev');

    INSERT INTO `aliases` (email, action, config) VALUES('quotas@test.dev','alias', '100quota@test.dev|1quota@test.dev');
