FROM alpine:3.23

# nginx + openssl
RUN apk add --no-cache \
    nginx \
    openssl

# Openssl autosigned certificate
RUN mkdir -p /etc/nginx/ssl && openssl req -x509 -noenc -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/C=FR/ST=PACA/L=Nice/O=42/OU=42/CN=jbarthel.42.fr"

# nginx configuration
COPY conf/docker.conf /etc/nginx/http.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
