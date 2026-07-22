# User documentation

This document explains how to use the Inception infrastructure once it is
installed. For installation and development, see `DEV_DOC.md`.

## What is provided

| Service | What it does |
|---|---|
| NGINX | Serves the site over HTTPS on port 443. The only entrypoint. |
| WordPress + php-fpm | Runs the site itself. |
| MariaDB | Stores the site content: articles, pages, users, settings. |

Only NGINX is reachable from outside. The database and php-fpm are only
reachable from within the Docker network.

## Starting and stopping

All commands are run from the root of the repository.

| Command | Effect |
|---|---|
| `make` | Start everything. Builds the images on first run. |
| `make ps` | Show whether the services are running. |
| `make logs` | Follow the logs. Press `Ctrl+C` to stop watching. |
| `make down` | Stop the site. **Data is preserved.** |

After `make`, allow a few seconds before the site answers: the containers start
in order, and WordPress waits for the database to accept connections.

## Accessing the site

Open `https://jbarthel.42.fr` in a browser.

The certificate is self-signed, so the browser shows a security warning on the
first visit. This is expected for a local project without a public certificate
authority. Choose "Advanced" and continue.

If the address does not resolve, the machine is missing its hosts entry. See
`DEV_DOC.md`.

## Accessing the administration

Go to `https://jbarthel.42.fr/wp-admin`.

Two accounts exist:

| Account | Role | Can do |
|---|---|---|
| `jbarthel` | Administrator | Everything: settings, themes, users, content |
| `guest` | Author | Write and publish their own articles only |

## Bonus services

Two additional services are reachable from the browser. Like the main site,
they need their subdomain to resolve locally — see the `/etc/hosts` step in
DEV_DOC.md if the pages do not load.

### Database administration — https://adminer.jbarthel.42.fr

Adminer is a single-file database client, served over HTTPS by the same nginx.
Log in with:

| Field    | Value      |
|----------|------------|
| System   | MySQL      |
| Server   | `mariadb`  |
| Username | `wpuser`   |
| Password | the content of `secrets/db_password.txt` |
| Database | `wordpress`|

`mariadb` is the container name: the database is never published on a port, so
it is only reachable from inside the Docker network — which is exactly why
Adminer runs as a container rather than on your host.

Once logged in, the `wp_posts` table holds the site's articles.

### Documentation site — https://static.jbarthel.42.fr

A static HTML page summarising this project, served by busybox httpd behind the
same nginx. It contains no PHP and no database access.

### File access — FTP on port 21

The WordPress directory is also reachable over FTP, from the machine running
the stack:

| Field    | Value       |
|----------|-------------|
| Host     | `127.0.0.1` |
| Port     | `21`        |
| Username | `nobody`    |
| Password | the content of `secrets/ftp_password.txt` |
| Mode     | passive     |

Files dropped there appear on the site immediately: uploading `notes.txt`
makes it available at `https://jbarthel.42.fr/notes.txt`.

The username is `nobody` because that is the account the web server itself
runs as, and it owns every file of the site. Anonymous access is refused.
FTP sends credentials in clear text, which is why the server is only reachable
from the local machine.

## Where the credentials are

**No password is stored in this repository.** They are in the `secrets/`
directory, which is excluded from version control and never committed.

| File | Password for |
|---|---|
| `secrets/db_root_password.txt` | MariaDB root account |
| `secrets/db_password.txt` | MariaDB WordPress account |
| `secrets/wp_admin_password.txt` | WordPress `jbarthel` account |
| `secrets/wp_user_password.txt` | WordPress `guest` account |
| `secrets/ftp_password.txt` | FTP account (`nobody`) |

On a fresh installation these files must be created by hand — see `DEV_DOC.md`.
The reference copies are kept in a password manager, not on disk.

## Checking that everything works

```sh
make ps
```

The three containers should show `Up`.

```sh
curl -kI https://jbarthel.42.fr
```

Should answer `HTTP/1.1 200 OK`. The `-k` flag tells curl to accept the
self-signed certificate.

If a service is listed as `Restarting`, read its logs before doing anything
else:

```sh
make logs
```

## Data and persistence

Content is stored outside the containers, in `/home/jbarthel/data`. It survives
`make down`, a reboot, and a rebuild of the images.

**`make fclean` and `make re` erase everything**: database, articles, users,
uploaded media. After either of them, the next `make` reinstalls a blank
WordPress site. Use them only when a fresh installation is what you want.

**Warning:** `make fclean` and `make re` delete the data with `sudo`, so they ask
for your user password. This is required because the data files are owned by
users that exist inside the containers, not on the host — your account cannot
remove them directly.
