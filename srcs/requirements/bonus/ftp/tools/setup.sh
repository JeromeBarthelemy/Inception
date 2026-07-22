#!/bin/sh
set -e

# FTP_USER is nobody: the account php-fpm already runs as, and the owner of
# every file under /var/www/html. No user to create, no ownership to change.
PASSWORD=$(cat /run/secrets/ftp_password)

echo "$FTP_USER:$PASSWORD" | chpasswd

# exec so vsftpd replaces the shell and becomes PID 1.
exec vsftpd /etc/vsftpd/vsftpd.conf
