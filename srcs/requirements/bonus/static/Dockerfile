FROM alpine:3.23

# busybox in the base image is built without the httpd applet, so busybox-extras is required
RUN apk add --no-cache busybox-extras

COPY site/ /var/www/html/           

EXPOSE 8080

CMD ["httpd", "-f", "-p", "8080", "-h", "/var/www/html"]

# busybox httpd installs no SIGTERM handler and the kernel ignores default
# signal actions for PID 1, so SIGTERM would stall until Docker's 10s timeout.
# Nothing to flush in a read-only file server: kill it directly.
STOPSIGNAL SIGKILL
