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

## Environment variables
- `MYSQL_HOST`: Server address of the MySQL server to use
- `MYSQL_USER`: Username to authenticate with
- `MYSQL_PASS`:  Password of the MySQL user
- `MYSQL_DATABASE`: Database name to use
- `HOSTNAME`:  Server hostname for the container