Mailserver with Haraka, Dovecot and MySQL
----------
Haraka SMTP Email Server with Dovecot and MySQL backend. This container includes services for SMTP, POP3 and IMAP.

**features:**

- Quota tracking
- Spam filtering
- MD5-Crypt authentication
- Forwarder (alias) support

## Requirement
- MySQL Server

## Installation
    docker pull mazelab/haraka-dovecot:latest

## Quick Start
Start a `mail` server instance:

    docker run --name some-mail -e HOSTNAME=mailserver.tld -d mazelab/haraka-dovecot

## Data Store
Account data is stored in MySQL.

### Maildir
**mailbox** : All mailboxes are stored in a volume at `/data/`

### Database
**users**: Contains the user info. e.g. login, maildir path, quota ...

**quota** : Contains the used mailbox size (dovecot will update this table automatically)

**forwarder** : Contains the rules of forwarder (aliases)

## Other
### Quota 
Dovecot keeps track of the current quota usage. MySQL is used to store the quota.

### SpamAssassin
E-mail spam filtering based on content-matching rules.

### Ports
- `SMTP`: 25
- `IMAP`: 143
- `POP3`: 110

## Database Design
The SQL queries are defined in config files and used by Haraka and Dovecot. When changing the tables you must modify the following SQL queries in:

- /etc/dovecot/**dovecot-sql.conf.ext**
- /srv/haraka/config/**aliases_mysql.ini**
- /srv/haraka/config/**auth_sql_cryptmd5.ini**
- /srv/haraka/config/**quota.check.ini**

### Create Tables
Create the tables like this: 

```sql
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `password` varchar(255) NOT NULL,
  `domain` varchar(255) NOT NULL,
  `uid` int(11) DEFAULT NULL,
  `gid` int(11) DEFAULT NULL,
  `gecos` varchar(255) DEFAULT NULL,
  `home` varchar(255) NOT NULL,
  `quota` varchar(255) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
```
```sql
CREATE TABLE `forwarder` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `address` varchar(128) NOT NULL,
  `action` varchar(8) NOT NULL,
  `aliases` text DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
```
```sql
CREATE TABLE `quota` (
  `username` varchar(255) NOT NULL,
  `bytes` bigint(20) NOT NULL DEFAULT '0',
  `messages` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`username`)
) ENGINE=InnoDB;
```
### Example datasets

Table *\`quota\`:*

username | bytes | messages
-------- | ----- | --------
foo@qux  | 1214  | 2
bar@qux  | 0     | 0

Table *\`forwarder\`:*

id | address | action | aliases
---| ------- | ------ | -------
1  | foo@qux | drop   | 
2  | bar@qux | alias  | foo@bar \| foo@qux

Table *\`users\`:*

id  | name| password  | domain | uid | gid | gecos | home          | quota
--- | --- | --------- | ------ | --- | --- | ----- | ------------- | -----
1   | baz | \$1\$x5b..| qux    | 8   | 8   | baz   | /data/qux/baz | 2

## Running the Mailserver
To create a new mail server for your domain you should use the following commands:

```shell
docker run -v /home/mail/dirs/:/data/
    -p 25:25 -p 110:110 -p 143:143
    -e HOSTNAME=yourdomain.com
    -e MYSQL_HOST=sql.yourdomain.com
    -e MYSQL_PORT=3306
    -e MYSQL_USER=username
    -e MYSQL_PASS=password
    -e MYSQL_DATABASE=mail
    --name mailserver mazelab/haraka-dovecot
```

Now you can access port 25, 110 and 143.

## Environment variables
- `MYSQL_HOST`: Server address of the MySQL server to use
- `MYSQL_USER`: Username to authenticate with
- `MYSQL_PASS`:  Password of the MySQL user
- `MYSQL_DATABASE`: Database name to use
- `HOSTNAME`:  Server hostname for the container