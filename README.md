Mailserver with Haraka, Dovecot and MySQL
----------
Haraka SMTP Email Server with Dovecot and MySQL backend. This container includes services for SMTP, POP3 and IMAP.

Please note that this is a highly experimental build.

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

#### Start a `mysql` instance
  
Skip if you want to use your own mysql server.

    docker run -d --name mysql-mail -e MYSQL_ROOT_PASSWORD=my-secret-pw -e MYSQL_DATABASE=mail-sample mysql

#### Start a `mail` server instance:

If you use your own mysql server you have to set the [environment variables](#environment-variables) accordingly. 

    docker run -d -v /home/mail/dirs/:/data/ -p 25:25 -p 110:110 -p 143:143 -e HOSTNAME=mail.dev --link mysql-mail:mysql -e MYSQL_HOST=mysql -e MYSQL_PORT=3306 -e MYSQL_USER=root -e MYSQL_PASS=my-secret-pw -e MYSQL_DATABASE=mail-sample --name mail-sample mazelab/haraka-dovecot

### File Permissions

Currently the mounted email dir must have the uid 8 which ist the standard mail user. So if you mounted into /data you have to set the permissions accordingly. Otherwise haraka will fail on local delivery and stop.

    # either
    chown -R mail: /home/mail
    # or
    chown -R 8:8 /home/mail

#### Setup database

To actually use the mail server you have to initialize the database.

Import the database structure.

If you used the above mysql container then do:

    docker exec -it mysql-mail mysql -u root -pmy-secret-pw mail-sample
    
Then copy/paste the dump and close the shell with `exit` 

Dump:
   
    /*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
    /*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
    /*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
    /*!40101 SET NAMES utf8 */;
    /*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
    /*!40103 SET TIME_ZONE='+00:00' */;
    /*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
    /*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
    /*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
    /*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
    
    --
    -- Table structure for table `expires`
    --
    
    /*!40101 SET @saved_cs_client     = @@character_set_client */;
    /*!40101 SET character_set_client = utf8 */;
    CREATE TABLE `expires` (
      `username` varchar(100) NOT NULL,
      `mailbox` varchar(255) NOT NULL,
      `expire_stamp` int(11) NOT NULL,
      PRIMARY KEY (`username`,`mailbox`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
    /*!40101 SET character_set_client = @saved_cs_client */;
    
    --
    -- Table structure for table `quota`
    --
    
    /*!40101 SET @saved_cs_client     = @@character_set_client */;
    /*!40101 SET character_set_client = utf8 */;
    CREATE TABLE `quota` (
      `username` varchar(100) NOT NULL,
      `bytes` bigint(20) NOT NULL DEFAULT '0',
      `messages` int(11) NOT NULL DEFAULT '0',
      PRIMARY KEY (`username`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
    /*!40101 SET character_set_client = @saved_cs_client */;
    
    --
    -- Table structure for table `users`
    --
    
    /*!40101 SET @saved_cs_client     = @@character_set_client */;
    /*!40101 SET character_set_client = utf8 */;
    CREATE TABLE `users` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `name` varchar(32) NOT NULL DEFAULT '',
      `password` varchar(255) NOT NULL DEFAULT '',
      `domain` varchar(255) NOT NULL DEFAULT '',
      `uid` int(11) DEFAULT NULL,
      `gid` int(11) DEFAULT NULL,
      `gecos` varchar(255) DEFAULT NULL,
      `home` varchar(255) DEFAULT NULL,
      `quota` varchar(255) DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY `stress_test_com_idx` (`name`)
    ) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
    /*!40101 SET character_set_client = @saved_cs_client */;
    
    /*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
    /*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
    /*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
    /*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
    /*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
    /*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
    /*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

### Add Domain

Haraka needs to know which domains are acceptable. Only email from these domains will be delivered.

    docker exec -it mail-sample sh -c 'echo "test.dev" >> /srv/haraka/config/host_list'

### Add User

Get the password first:

    docker exec mail-sample doveadm pw -s MD5-CRYPT -p thepassword
    {MD5-CRYPT}$1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/ -> password string is $1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/

Go into mysql again:

    docker exec -it mysql-mail mysql -u root -pmy-secret-pw mail-sample
    
Use query to add new users:

    // email test@test.dev, pw: thepassword, 100 MB quota
    INSERT INTO `users` (name, password, domain, uid, gid, gecos, home, quota) VALUES('test','$1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/','test.dev',1,0,'this is just a test','/data/test.dev/test','100');

    // email testquota@test.dev, pw: thepassword, 1 MB quota
    INSERT INTO `users` (name, password, domain, uid, gid, gecos, home, quota) VALUES('testquota','$1$DpBbHS.2$vHGFpWG4V0aR24JpkiusC/','test.dev',1,0,'this is just a quota test','/data/test.dev/quota','1');


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
- `IMAP`: 143 or 993 (SSL/TLS)
- `POP3`: 110 or 995 (SSL/TLS)

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

## SSL configuration
The placement of files enables the use of SSL/TLS (and STARTTLS).

#### Certificate Location
Use `/tls/` volume to mount a directory inside the container with the key files.

```
/tls/tls_key.pem
/tls/tls_cert.pem
```

### Password protected key files
SSL key files may be password protected. Use the `SSL_KEY_PASSWORD` environment variable on Docker to provide the password.

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
- `SSL_KEY_PASSWORD`:  Password for protected SSL key files
