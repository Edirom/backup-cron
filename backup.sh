#!/bin/bash

# set current date
TODAY=$(date +%Y-%m-%d)

# logfile location
LOGFILE=/var/log/backup.log

# lockfile location
LOCKFILE=/var/run/$(basename $0).lock

# array of source directories (on the source host)
SOURCE[0]=/var/backup-master-volume/

# hosts and credentials
BACKUP_HOST=192.168.24.9
BACKUP_HOST_USER=root

# backup location (on the backup host)
TARGET=/raid0/data/rancher-nfs-backups

# ******************************************
# Nothing to edit below
# ******************************************
touch $LOGFILE || { echo "Cannot write to logfile. Try running with sudo" >&2; exit 1; }

echo "************************************************************" >> $LOGFILE 
echo "$(date): starting backup job" >> $LOGFILE 
echo "************************************************************" >> $LOGFILE 

# trying to create a lockfile to prevent double execution of this script
[ -f $LOCKFILE ] && {
  echo "$(basename $0) already running" >> $LOGFILE ;
  exit 1;
}
touch $LOCKFILE || { echo "Cannot write lockfile. Try running with sudo" >&2; exit 1; }

# copying (= creating hard links) the latest backup on the backup host as a starting point for todays backup
# first, check whether the folder already exists
if ( ssh -o StrictHostKeyChecking=no $BACKUP_HOST_USER@$BACKUP_HOST "[ -d $TARGET/$TODAY ]") ; then
    echo "$(date): Backup directory $TARGET/$TODAY already exists" >> $LOGFILE ;
    echo "$(date): We simply update $TARGET/$TODAY via rsync" >> $LOGFILE ;
else
    echo "$(date): copying yesterdays backup as a starting point for todays backup" >> $LOGFILE ; 
    ssh -o StrictHostKeyChecking=no $BACKUP_HOST_USER@$BACKUP_HOST "cp -al $TARGET/latest/. $TARGET/$TODAY" >> $LOGFILE 2>&1 ;
fi

# now running rsync (without compression!) for every folder on the source host
for i in "${SOURCE[@]}" 
    do 
        echo "$(date): rsyncing $i …" >> $LOGFILE 
        rsync -a --stats --delete $i $BACKUP_HOST:$TARGET/$TODAY >> $LOGFILE 2>&1 
    done

# switch symlink "latest" when operations succeeded
echo "$(date): Switching symbolic link \"latest\" to new backup \"$TODAY\"" >> $LOGFILE
ssh $BACKUP_HOST_USER@$BACKUP_HOST "rm -f $TARGET/latest" >> $LOGFILE 2>&1
ssh $BACKUP_HOST_USER@$BACKUP_HOST "cd $TARGET ; ln -s $TODAY latest" >> $LOGFILE 2>&1

# last action:  removing lockfile
rm $LOCKFILE >> $LOGFILE 2>&1

echo "************************************************************" >> $LOGFILE 
echo "$(date): finished creating backup \"$TODAY\"" >> $LOGFILE
echo "************************************************************" >> $LOGFILE
