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
```

## Repository layout

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── .env.example
├── tools/
│   └── healthcheck.sh
├── secrets/                     (git-ignored)
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   ├── wp_user_password.txt
│   └── ftp_password.txt
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
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/docker.conf
        └── bonus/
            ├── redis/
            │   ├── Dockerfile
            │   └── conf/redis.conf
            ├── adminer/
            │   ├── Dockerfile
            │   └── conf/www.conf
            ├── static/
            │   ├── Dockerfile
            │   └── site/
            │       ├── index.html
            │       └── style.css
            ├── ftp/
            │   ├── Dockerfile
            │   ├── conf/vsftpd.conf
            │   └── tools/setup.sh
            └── netdata/
                ├── Dockerfile
                └── conf/netdata.conf
```

`.gitignore` excludes `srcs/.env` and `secrets/` — no credential has ever been
committed to this repository.

## Setting up a fresh environment

### 1. Domain resolution


The site and its bonus services are served on subdomains of `jbarthel.42.fr`,
which must all resolve to the local machine:

```sh
echo "127.0.0.1 jbarthel.42.fr adminer.jbarthel.42.fr static.jbarthel.42.fr netdata.jbarthel.42.fr" | sudo tee -a /etc/hosts
ping -c1 jbarthel.42.fr
```

### 2. Environment file

`srcs/.env` is not committed. Create it from the template:

```sh
cp .env.example srcs/.env
```

It holds only non-sensitive values: domain name, database name, WordPress user
names, site title and URL. No password belongs in this file.

### 3. Secrets

Create one file per password, each containing the password and nothing else:

```sh
mkdir -p secrets
printf '%s' 'CHANGE_ME' > secrets/db_root_password.txt
printf '%s' 'CHANGE_ME' > secrets/db_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_admin_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_user_password.txt
printf '%s' 'CHANGE_ME' > secrets/ftp_password.txt
```

`printf` is used rather than `echo` to avoid a trailing newline, which would
become part of the password.

Docker mounts these files at `/run/secrets/<name>` inside the containers, as
read-only bind mounts of the host files. The init scripts read them from there.
No password is ever passed as an environment variable, and none appears in
`docker inspect` — only the path of the secret does.

Check before the first commit that nothing sensitive is tracked:

```sh
git status
git check-ignore -v srcs/.env secrets/
```

### 4. Build and start

```sh
make
```

This creates `/home/jbarthel/data/{mariadb,wordpress}` if needed, builds the
three images, and starts the stack.

## Make targets

| Target | Effect |
|---|---|
| `all` / `make` | Create data directories, build, start |
| `build` | Build the images without starting |
| `up` | Same as `all` |
| `down` | Stop and remove containers; volumes and data are kept |
| `clean` | `down` plus removal of the Docker volumes |
| `fclean` | `clean` plus removal of images and of the data on disk |
| `re` | `fclean` then a full rebuild |
| `logs` | Follow all logs |
| `ps` | Container status |

`fclean` and `re` remove the data with `sudo` and will ask for your user
password. This is required because the data files are owned by users that exist
inside the containers, not on the host.

Compose is always invoked as
`docker compose -f srcs/docker-compose.yml <command>`, since the Compose file
is not at the repository root.

Because the Compose file lives in `srcs/`, the project name is `srcs`. Resources
are therefore named `srcs_inception` (network), `srcs_db_data` and `srcs_wp_data`
(volumes).

## Useful commands

### Containers

```sh
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f nginx
docker exec -it nginx sh
docker exec nginx ps aux
```

`ps aux` inside a container should show the service itself as PID 1 — not a
shell or a wrapper script. This matters: PID 1 is what receives `SIGTERM` when
Docker stops the container, so a wrong PID 1 means a forced kill after the
10-second grace period.

### Database

```sh
docker exec -it mariadb mariadb -u root -p
```

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;
```

### Volumes and network

```sh
docker volume ls
docker volume inspect srcs_wp_data
docker network inspect srcs_inception
```

### Configuration

```sh
docker compose -f srcs/docker-compose.yml config
docker exec nginx nginx -t
```

`config` prints the fully resolved Compose file with `.env` values substituted —
useful to confirm that no secret leaks into it.

Note that `nginx -t` resolves upstream host names at parse time. Running it in a
container that is not attached to the project network fails with
`host not found in upstream "wordpress"`, even though the configuration is
correct.

## How data persists

Two named volumes are declared with `driver_opts` so that their contents live in
a known host directory:

| Volume | Container path | Host path |
|---|---|---|
| `db_data` | `/var/lib/mysql` | `/home/jbarthel/data/mariadb` |
| `wp_data` | `/var/www/html` | `/home/jbarthel/data/wordpress` |

`wp_data` is mounted into both `wordpress` and `nginx`: php-fpm executes the PHP
files, NGINX serves the static ones. It is the same data seen by two containers.

Both init scripts are guarded so that initialisation happens only once:

- `tools/init.sh` checks `[ ! -d /var/lib/mysql/mysql ]` before bootstrapping
  the database
- `tools/setup.sh` checks `[ ! -f wp-config.php ]` before installing WordPress

This is why `make down && make` preserves everything while `make re` starts from
a blank slate. To verify the guards after any change:

```sh
make down && make
sleep 15
docker compose -f srcs/docker-compose.yml logs wordpress | grep -c "First boot"
```

The count must be `0` after a restart, and `1` after `make re`. Checking the
database directly is even more reliable — a fresh install contains only the
default "Hello world!" article:

```sh
docker exec -it mariadb mariadb -u root -p -e \
  "USE wordpress; SELECT ID, post_title FROM wp_posts WHERE post_type='post';"
```

Note that `docker compose down -v` removes the volume declarations but does not
delete the host directories, because the volumes are backed by bind mounts.
`make fclean` therefore removes those directories explicitly.

## Bonus services

Three optional containers run alongside the mandatory stack. None of them
publishes a port: Adminer and the static site are served by the same nginx over
HTTPS on their own subdomain, and Redis is reachable only from the Docker
network.

### Redis (object cache)

Redis is wired to WordPress in two places: the `php83-pecl-redis` extension is
installed in the wordpress image (without it the plugin connects to nothing and
fails silently), and the first-boot script installs the `redis-cache` plugin,
sets `WP_REDIS_HOST` to `redis` and enables the drop-in.

docker exec wordpress wp redis status --path=/var/www/html
### Adminer (database client)

A single PHP file served through php-fpm, on `adminer.jbarthel.42.fr`. nginx
passes it the script name only, so no volume is shared with this container.

### Static site (documentation)

Plain HTML served by busybox httpd on `static.jbarthel.42.fr`. nginx reverse-
proxies it rather than reading its files, which is why this container shares no
volume either. Note that busybox's httpd applet is not in the Alpine base image
— the Dockerfile installs `busybox-extras` — and that it installs no SIGTERM
handler, hence the `STOPSIGNAL SIGKILL` line that keeps `make down` fast.

### FTP (vsftpd)

vsftpd runs in the foreground as PID 1. The password comes from the
`ftp_password` secret and is applied at startup by `tools/setup.sh`, which
then `exec`s vsftpd. No user is created: the FTP account is `nobody`, which
already owns `/var/www/html`, so no ownership or permission change is needed.

Two settings exist only to work around Alpine specifics, and both are
commented in `conf/vsftpd.conf`:

- `check_shell=NO` — Alpine builds vsftpd without PAM, so vsftpd checks the
  account's shell against `/etc/shells` itself. `nobody` uses `/sbin/nologin`,
  which is deliberately not listed there.
- `seccomp_sandbox=NO` — vsftpd's sandbox misbehaves on musl.

Passive mode uses ports 21100-21105, published as-is on the host, and
`pasv_address` is fixed to `127.0.0.1`. Connecting from another machine would
require changing that address: vsftpd would otherwise advertise its internal
`172.x` address, which no external client can reach.

This is the only service besides nginx that publishes ports. FTP is not HTTP,
so nginx cannot proxy it.

### Netdata (monitoring)

`netdata -D` keeps the daemon in the foreground as PID 1. The container gets no
volume, no secret and no privileges.

`conf/netdata.conf` sets only two things: `[db] mode = ram`, so metrics stay in
memory and no volume is needed, and `[web] bind to = *` with the port nginx
proxies to. Note that the configuration schema changed across versions —
`memory mode` and `history` no longer exist, and unknown keys are ignored
silently. Read the daemon's effective configuration with
`docker exec netdata wget -qO- http://localhost:19999/netdata.conf`: keys left
at their default are commented out, applied ones are not.

Telemetry is disabled by the `/etc/netdata/.opt-out-from-anonymous-statistics`
sentinel file created in the Dockerfile; there is no config key for it in this
version.

`curl -I` returns `400` on this vhost: netdata does not implement HEAD. Test it
with a GET.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `502 Bad Gateway` | php-fpm not reachable — check `fastcgi_pass` and that `wordpress` is up |
| `404` on every page | `wp_data` empty or not mounted — check the volume |
| Infinite redirect on `/wp-admin` | `fastcgi_param HTTPS on;` missing from the NGINX config |
| Container stuck `Restarting` | Read its logs; often a failed dependency at startup |
| `host not found in upstream` | NGINX started before WordPress had a DNS entry |
| `rm: Permission denied` on `make fclean` | Data files are owned by in-container users; the recipe needs `sudo` |

When testing, never use `curl -s`: it silences connection errors, so a failed
request looks the same as an empty response.
