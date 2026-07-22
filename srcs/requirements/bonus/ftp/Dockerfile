FROM alpine:3.23

RUN apk add --no-cache vsftpd

# secure_chroot_dir points here; the package does not ship the directory.
RUN mkdir -p /var/empty

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/setup.sh /setup.sh
RUN chmod +x /setup.sh

EXPOSE 21

# vsftpd installs no SIGTERM handler and the kernel ignores default signal
# actions for PID 1, so SIGTERM would stall until Docker's 10s timeout.
STOPSIGNAL SIGKILL

CMD ["/setup.sh"]
