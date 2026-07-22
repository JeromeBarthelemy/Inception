FROM alpine:3.23

RUN apk add --no-cache netdata

# No usage statistics leave this infrastructure. In this version the opt-out is
# a sentinel file, not a netdata.conf key.
RUN touch /etc/netdata/.opt-out-from-anonymous-statistics

COPY conf/netdata.conf /etc/netdata/netdata.conf

EXPOSE 19999

# -D keeps the daemon in the foreground so it stays PID 1, like httpd -f
# and vsftpd's background=NO.
CMD ["netdata", "-D"]
