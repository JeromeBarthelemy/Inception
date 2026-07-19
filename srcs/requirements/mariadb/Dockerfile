FROM alpine:3.23

RUN apk update && apk add --no-cache mariadb mariadb-client

COPY conf/docker.cnf /etc/my.cnf.d/docker.cnf

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]
