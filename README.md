*This project has been created as part of the 42 curriculum by jbarthel*

# Inception

## Description

Inception builds a small WordPress infrastructure from scratch inside a Debian
virtual machine, orchestrated with Docker Compose. Every image is written by
hand — no ready-made images are pulled from Docker Hub.

The stack is made of three mandatory containers, each running a single service:

| Service | Role | Exposed |
|---|---|---|
| `nginx` | TLS entrypoint, serves static files, forwards PHP to php-fpm | `443` only |
| `wordpress` | WordPress + php-fpm, no web server of its own | `9000`, internal |
| `mariadb` | Database, no web server of its own | `3306`, internal |

Every image in this project — mandatory and bonus alike — is built
`FROM alpine:3.23`, the penultimate stable release, as required. The `latest`
tag is never used.

The site is reachable at `https://jbarthel.42.fr`, which resolves to the local
machine through `/etc/hosts`. NGINX is the only entrypoint: it listens on port
443 with a self-signed certificate and accepts TLSv1.2 and TLSv1.3 only.

Persistent data lives in two named volumes backed by `/home/jbarthel/data`:
one for the database, one for the WordPress files.

Five bonus containers run alongside the mandatory stack:

| Service | Role | Exposed |
|---|---|---|
| `redis` | Object cache for WordPress: query results are kept in memory instead of being re-fetched from MariaDB on every page load | none |
| `adminer` | Web database client, served by nginx on `adminer.jbarthel.42.fr` | none |
| `static` | Static documentation site, no PHP, reverse-proxied by nginx on `static.jbarthel.42.fr` | none |
| `ftp` | vsftpd server giving access to the WordPress volume, so files can be dropped straight into the site | `21` and `21100-21105` |
| `netdata` | Real-time monitoring dashboard, reverse-proxied by nginx on `netdata.jbarthel.42.fr` | none |

Only `ftp` publishes ports besides nginx: FTP is not HTTP, so nginx cannot
proxy it. The other four are reachable only through nginx or from inside the
Docker network.

Netdata reports the host machine's CPU and memory, because Docker does not
namespace `/proc`: the kernel counters a container reads are the host's. It is
granted no privileges, no host mounts and no access to the Docker socket, so it
cannot break anything down per container — it observes the machine, not the
infrastructure.

Both outbound channels are disabled: anonymous statistics through a sentinel
file, and Netdata Cloud through `cloud.d/cloud.conf`. Without the latter the
dashboard tries to load a sign-in frame from `app.netdata.cloud`.

### Virtual Machine vs Docker

A virtual machine emulates a complete computer: it boots its own kernel on top
of a hypervisor, with its own memory and virtual disks. Isolation is strong,
but each VM carries a full operating system.

A container shares the host kernel. It is a process — or a group of processes —
isolated by kernel features: namespaces partition what the process can see
(its own PID tree, network stack, mount table), and cgroups limit what it can
consume. There is no second kernel, no boot sequence, no emulated hardware.

The difference is measurable in this project. Stopping the whole stack takes
about one second, because Docker sends `SIGTERM` to three processes that exit
immediately. Shutting down the Debian VM that hosts them takes far longer,
because a real kernel has to unmount filesystems and halt devices.

Containers do not replace virtual machines. The isolation is weaker — a kernel
vulnerability is shared by every container on the host. That is precisely why
this project runs Docker *inside* a VM rather than directly on the host.

### Secrets vs Environment variables

Both inject configuration at runtime, but they differ in exposure.

Environment variables are readable by anyone who can run `docker inspect` on
the container, and they leak into logs and crash reports. They suit values that
are not sensitive: the domain name, the database name, the WordPress user name.
Those live in `srcs/.env`, which is git-ignored, with a `.env.example` committed
to document the required keys.

Docker mounts each secret read-only under `/run/secrets/<name>`. In this
project (standalone Compose with file-based secrets) it is a read-only bind
mount of the host file — the password is never copied into an image layer and
never appears as an environment variable in `docker inspect`. Every password
goes through that path: the init scripts read the file, never an environment
variable.

Neither mechanism puts anything in the image itself. A password baked into a
Dockerfile stays in the layer history forever, readable by anyone who pulls the
image, even if a later layer deletes the file.

### Docker network vs host network

Each container joins a user-defined bridge network. It is declared as
`inception` in `docker-compose.yml`; Docker prefixes it with the Compose project
name, so the actual network is `srcs_inception`. Docker runs an embedded DNS
resolver on it, so containers reach each other by service name: NGINX forwards
PHP requests to `wordpress:9000` without ever knowing an IP address. This is why
the legacy `--link` flag is unnecessary — and why the subject forbids it.

The isolation is the point. Only NGINX publishes a port to the host. MariaDB
listens on 3306 and WordPress on 9000, but both are reachable only from inside
the network. There is no route from the outside world to the database.

Using `network_mode: host` would place containers directly on the host network
stack. Service-name resolution would disappear, every listening port would be
exposed at once, and two containers could not bind the same port. The subject
forbids it for those reasons.

### Volumes vs bind mounts

A bind mount maps a host path straight into a container. It is simple, but the
container depends on the host's directory layout, and Docker manages nothing.

A named volume is managed by Docker: it has a name, a lifecycle, and it survives
`docker compose down`. This project uses two named volumes, as the subject
requires. They are declared as `db_data` and `wp_data` in `docker-compose.yml`;
like the network, Docker prefixes them with the Compose project name, so the
actual volumes are `srcs_db_data` and `srcs_wp_data`.

There is a subtlety worth knowing here. Both volumes are declared with
`driver_opts` so their contents land in `/home/jbarthel/data`, as the subject
also requires. They are named volumes with a bind-mounted backing store. The
practical consequence is that `docker compose down -v` removes the volume
*declaration* but leaves the host directories untouched — which is why
`make fclean` deletes those directories explicitly. Without that, a "clean
rebuild" would silently restart on the old database.

## Instructions

### Prerequisites

- Docker Engine and the Docker Compose plugin
- `make`
- An entry in `/etc/hosts`: `127.0.0.1 jbarthel.42.fr adminer.jbarthel.42.fr static.jbarthel.42.fr netdata.jbarthel.42.fr`

### Setup

The repository does not contain any credentials. Before the first build, create
`srcs/.env` from `.env.example`, then create the secret files:

    secrets/db_root_password.txt
    secrets/db_password.txt
    secrets/wp_admin_password.txt
    secrets/wp_user_password.txt
    secrets/ftp_password.txt

Each file contains a single password and nothing else. Both `srcs/.env` and
`secrets/` are git-ignored. See `DEV_DOC.md` for the full procedure.

### Usage

| Command | Effect |
|---|---|
| `make` | Create the data directories, build the images, start the stack |
| `make down` | Stop and remove the containers; data is kept |
| `make clean` | `make down` plus removal of the Docker volumes |
| `make fclean` | `make clean` plus deletion of the images and of the data on disk |
| `make re` | `make fclean` followed by a full rebuild |
| `make logs` | Follow the logs of all services |
| `make ps` | Show the state of the containers |

The site is then available at `https://jbarthel.42.fr`. The certificate is
self-signed, so browsers show a warning on first visit — this is expected.

**`make fclean` destroys the database and the WordPress installation.** After it,
the next `make` performs a fresh install: new site, no articles.

## Resources

**Subject**
- Inception, subject version 5.3

**Docker**
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Manage secrets securely in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Networking overview](https://docs.docker.com/engine/network/)
- [Volumes](https://docs.docker.com/engine/storage/volumes/)
- [Start containers automatically](https://docs.docker.com/engine/containers/start-containers-automatically/)

**Alpine Linux**
- [Alpine package index](https://pkgs.alpinelinux.org/packages)

**NGINX**
- [Module ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Module ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

**TLS**
- [openssl-req](https://docs.openssl.org/master/man1/openssl-req/)

**WordPress**
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)

**MariaDB**
- [mysql_install_db](https://mariadb.com/kb/en/mysql_install_db/)

## Use of AI

This project was built with the assistance of AI, used as a
guide rather than as a code generator.

The workflow was deliberate: for each service, the assistant explained what the
file had to accomplish and why, and I wrote it myself. My drafts were then
reviewed, and I corrected the mistakes.

The assistant was also used to debug three Alpine-specific problems in the
WordPress and MariaDB images, and to understand why `docker kill` does not
trigger a restart policy — Docker deliberately ignores the policy when the stop
is manual, and the kernel drops `SIGKILL` sent to PID 1 from inside its own
namespace.
