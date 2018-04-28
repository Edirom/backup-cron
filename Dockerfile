# Backup script to create daily backups
# and write those to a remote machine via rsync/ssh
# On the remote machine, every new backup is derived from
# last day's backup by setting hard links.
# Afterwards rsync will update the changed files

FROM alpine:3.7

LABEL maintainer="Peter Stadler for the ViFE"

RUN apk --update \
    add --no-cache  bash openssh-client rsync \
    && rm -rf /var/cache/apk/*

# copy our backup script to the daily cron job
# which will run at 2 AM.
# NB: the script must not be suffixed with any extension name
COPY backup.sh /etc/periodic/daily/backup

# forward backup logs to docker log collector
RUN ln -sf /dev/stdout /var/log/backup.log

CMD ["crond", "-l2", "-f"]