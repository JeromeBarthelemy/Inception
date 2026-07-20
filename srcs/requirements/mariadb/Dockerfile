FROM alpine:3.23

RUN apk add --no-cache mariadb mariadb-client

# Disable the default config's skip-networking so the DB is reachable over TCP
RUN sed -i 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf

COPY conf/docker.cnf /etc/my.cnf.d/docker.cnf

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]
