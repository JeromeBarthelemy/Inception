#!/bin/sh
set -e

# --- Read secrets ---
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# --- Wait until MariaDB accepts our connection ---
echo "Waiting for MariaDB..."
until mariadb -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; do
    sleep 2
done
echo "MariaDB is ready."

cd /var/www/html

# --- First boot? (wp-config.php does not exist yet) ---
if [ ! -f wp-config.php ]; then
    echo "First boot: installing WordPress..."

    wp core download --allow-root

    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="mariadb:3306"

    wp core install --allow-root \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"

    wp plugin install --allow-root redis-cache --activate
    wp config set --allow-root WP_REDIS_HOST redis
    wp redis enable --allow-root

    wp user create --allow-root \
        "$WP_USER" "$WP_USER_EMAIL" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD"

    echo "WordPress installed."
else
    echo "WordPress already installed, skipping."
fi

# --- Ensure php-fpm workers (nobody) own the files ---
chown -R nobody:nobody /var/www/html

# --- Start php-fpm in the foreground, as PID 1 ---
exec php-fpm83 -F
