# Developer documentation

How to set up, build and operate this project from scratch.

## Requirements

- A Linux machine or virtual machine
- Docker Engine and the Docker Compose plugin (v2)
- `make` — not installed by default on a minimal Debian; `sudo apt install make`
- A user in the `docker` group, or `sudo` in front of every Docker command

Verify:

```sh
docker --version
docker compose version
make --version

Repository layout

.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .env.example
├── secrets/                     (git-ignored)
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── docker-compose.yml
    ├── .env                     (git-ignored)
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/docker.cnf
        │   └── tools/init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/setup.sh
        └── nginx/
            ├── Dockerfile
            └── conf/docker.conf

Setting up a fresh environment

1. Domain resolution

The site is served on jbarthel.42.fr, which must resolve to the local machine:

echo "127.0.0.1 jbarthel.42.fr" | sudo tee -a /etc/hosts
ping -c1 jbarthel.42.fr

2. Environment file

srcs/.env is not committed. Create it from the template:

cp .env.example srcs/.env

It holds only non-sensitive values: domain name, database name, WordPress user
names, site title and URL. No password belongs in this file.

3. Secrets

Create one file per password, each containing the password and nothing else:

mkdir -p secrets
printf '%s' 'CHANGE_ME' > secrets/db_root_password.txt
printf '%s' 'CHANGE_ME' > secrets/db_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_admin_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_user_password.txt

printf is used rather than echo to avoid a trailing newline, which would
become part of the password.

Docker mounts these files at /run/secrets/<name> inside the containers, in
memory. The init scripts read them from there. No password is ever passed as an
environment variable, and none appears in docker inspect.

Check before the first commit that nothing sensitive is tracked:

git status
git check-ignore -v srcs/.env secrets/db_password.txt

4. Build and start

make

This creates /home/jbarthel/data/{mariadb,wordpress} if needed, builds the
three images, and starts the stack.

Make targets

┌────────────┬───────────────────────────────────────────────────────┐
│   Target   │                        Effect                         │
├────────────┼───────────────────────────────────────────────────────┤
│ all / make │ Create data directories, build, start                 │
├────────────┼───────────────────────────────────────────────────────┤
│ build      │ Build the images without starting                     │
├────────────┼───────────────────────────────────────────────────────┤
│ up         │ Same as all                                           │
├────────────┼───────────────────────────────────────────────────────┤
│ down       │ Stop and remove containers; volumes and data are kept │
├────────────┼───────────────────────────────────────────────────────┤
│ clean      │ down plus removal of the Docker volumes               │
├────────────┼───────────────────────────────────────────────────────┤
│ fclean     │ clean plus removal of images and of the data on disk  │
│            │   (user password needed)                              │
├────────────┼───────────────────────────────────────────────────────┤
│ re         │ fclean then a full rebuild (user password needed)     │
├────────────┼───────────────────────────────────────────────────────┤
│ logs       │ Follow all logs                                       │
├────────────┼───────────────────────────────────────────────────────┤
│ ps         │ Container status                                      │
└────────────┴───────────────────────────────────────────────────────┘

Compose is always invoked as
docker compose -f srcs/docker-compose.yml <command>, since the Compose file
is not at the repository root.

Because the Compose file lives in srcs/, the project name is srcs. Resources
are therefore named srcs_inception (network), srcs_db_data and srcs_wp_data
(volumes).

Useful commands

Containers

docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f nginx
docker exec -it nginx sh
docker exec nginx ps aux

ps aux inside a container should show the service itself as PID 1 — not a
shell or a wrapper script. This matters: PID 1 is what receives SIGTERM when
Docker stops the container, so a wrong PID 1 means a forced kill after the
10-second grace period.

Database

docker exec -it mariadb mariadb -u root -p

SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;

Volumes and network

docker volume ls
docker volume inspect srcs_wp_data
docker network inspect srcs_inception

Configuration

docker compose -f srcs/docker-compose.yml config
docker exec nginx nginx -t

config prints the fully resolved Compose file with .env values substituted —
useful to confirm that no secret leaks into it.

Note that nginx -t resolves upstream host names at parse time. Running it in a
container that is not attached to the project network fails with
host not found in upstream "wordpress", even though the configuration is
correct.

How data persists

Two named volumes are declared with driver_opts so that their contents live in
a known host directory:

┌─────────┬────────────────┬───────────────────────────────┐
│ Volume  │ Container path │           Host path           │
├─────────┼────────────────┼───────────────────────────────┤
│ db_data │ /var/lib/mysql │ /home/jbarthel/data/mariadb   │
├─────────┼────────────────┼───────────────────────────────┤
│ wp_data │ /var/www/html  │ /home/jbarthel/data/wordpress │
└─────────┴────────────────┴───────────────────────────────┘

wp_data is mounted into both wordpress and nginx: php-fpm executes the PHP
files, NGINX serves the static ones. It is the same data seen by two containers.

Both init scripts are guarded so that initialisation happens only once:

- tools/init.sh checks [ ! -d /var/lib/mysql/mysql ] before bootstrapping
the database
- tools/setup.sh checks [ ! -f wp-config.php ] before installing WordPress

This is why make down && make preserves everything while make re starts from
a blank slate. To verify that the guards work after any change:

make down && make
sleep 15
docker compose -f srcs/docker-compose.yml logs wordpress | grep -ci "core install"

The count must be 0. A non-zero value means WordPress reinstalled itself,
which would destroy existing content on every restart.

Note that docker compose down -v removes the volume declarations but does not
delete the host directories, because the volumes are backed by bind mounts.
make fclean therefore removes those directories explicitly.

Troubleshooting

┌──────────────────────────────────────┬─────────────────────────────────────────────────────────────────────┐
│            Symptom                   │                            Likely cause                             │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ 502 Bad Gateway                      │ php-fpm not reachable — check fastcgi_pass and that wordpress is up │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ 404 on every page                    │ wp_data empty or not mounted — check the volume                     │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ Infinite redirect on /wp-admin       │ fastcgi_param HTTPS on; missing from the NGINX config               │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ Container stuck Restarting           │ Read its logs; often a failed dependency at startup                 │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ host not found in upstream           │ NGINX started before WordPress had a DNS entry                      │
├──────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┤
│ rm: Permission denied on make fclean │ Data files are owned by in-container users; the recipe needs sudo   │
└──────────────────────────────────────┴─────────────────────────────────────────────────────────────────────┘


When testing, never use curl -s: it silences connection errors, so a failed
request looks the same as an empty response.
