#!/bin/sh
set -e

# --- 1. Read secrets ---
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

# --- 2. Prepare the socket directory ---
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# --- 3. First boot? (the system database does not exist yet) ---
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First boot: initializing MariaDB..."
    chown -R mysql:mysql /var/lib/mysql

    # 3a. Create the system tables
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    # 3b. Create the database, user and passwords (bootstrap mode)
    mariadbd --user=mysql --bootstrap <<EOF
USE mysql;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    echo "Initialization done."
else
    echo "MariaDB already initialized, skipping."
fi

# --- 4. Start the server in the foreground, as PID 1 ---
exec mariadbd --user=mysql
