FROM alpine:3.23

RUN apk add --no-cache vsftpd

# secure_chroot_dir points here; the package does not ship the directory.
RUN mkdir -p /var/empty

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/setup.sh /setup.sh
RUN chmod +x /setup.sh

EXPOSE 21

CMD ["/setup.sh"]
