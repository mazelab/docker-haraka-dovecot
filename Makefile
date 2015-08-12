.PHONY: build run

build:
	sudo docker build --rm=true -t mazelab/haraka-dovecot .

run:
	sudo docker run -ti --rm=true --name haraka-dovecot mazelab/haraka-dovecot /bin/sh

test:
	sudo docker run -ti --rm=true -p 25:25 -p 110:110 -p 143:143 -e HOSTNAME=test.dev -e MYSQL_HOST=localhost -e MYSQL_PORT=3306 -e MYSQL_USER=root -e MYSQL_PASS=root -e MYSQL_DATABASE=vpopmail --name haraka-dovecot mazelab/haraka-dovecot