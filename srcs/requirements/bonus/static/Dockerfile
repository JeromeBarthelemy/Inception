FROM alpine:3.23

# busybox in the base image is built without the httpd applet, so busybox-extras is required
RUN apk add --no-cache busybox-extras

COPY site/ /var/www/html/           

EXPOSE 8080

CMD ["httpd", "-f", "-p", "8080", "-h", "/var/www/html"]
