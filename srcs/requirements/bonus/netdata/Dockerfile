FROM alpine:3.23

RUN apk add --no-cache netdata

# The agent sends no usage statistics: in this version the opt-out is a sentinel
# file, not a netdata.conf key.
RUN touch /etc/netdata/.opt-out-from-anonymous-statistics

# Netdata Cloud is a separate mechanism from anonymous statistics: the dashboard
# otherwise tries to load a sign-in frame from app.netdata.cloud. Disable it so
# the agent never reaches outside this machine.
RUN mkdir -p /var/lib/netdata/cloud.d \
 && printf '[global]\n    enabled = no\n' > /var/lib/netdata/cloud.d/cloud.conf


COPY conf/netdata.conf /etc/netdata/netdata.conf

EXPOSE 19999

# -D keeps the daemon in the foreground so it stays PID 1, like httpd -f
# and vsftpd's background=NO.
CMD ["netdata", "-D"]
