#!/bin/bash

##############################################
# Backup script, using rsync over SSH 
#
# 
# we expect the following parameters 
# to be exported in the environment:
#
# * BACKUP_TARGET_HOST
# * BACKUP_TARGET_PATH
# * BACKUP_SOURCE_PATH
#
# If BACKUP_SOURCE_HOST is given as well,
# we are backing up remote2remote,
# otherwise the default is to back up the  
# local data at BACKUP_SOURCE_PATH
#
# Second, we expect a working SSH connection
# (with keyfiles) between localhost and both 
# BACKUP_TARGET_HOST and BACKUP_SOURCE_HOST (if given).
# If given, the BACKUP_SOURCE_HOST will need to be
# able to connect to the BACKUP_TARGET_HOST, as well.
##############################################

# set current date
TODAY=$(date +%Y-%m-%d)

# logfile location
LOGFILE=/var/log/backup.log

# lockfile location
LOCKFILE=/var/run/$(basename $0).lock

# we expect the following parameters to be exported:
#
# * BACKUP_TARGET_HOST
# * BACKUP_TARGET_PATH
# * BACKUP_SOURCE_PATH
#
# so we check for these and abort if unset
for PARAM in BACKUP_TARGET_HOST BACKUP_TARGET_PATH BACKUP_SOURCE_PATH
do 
    if [ -z "${!PARAM}" ]
    then
        echo "ERROR: ${PARAM} not set. Aborting."
        exit 1
    fi
done

# reading $BACKUP_SOURCE_PATH into array $SOURCES
readarray -td ',' SOURCES < <( echo -e $BACKUP_SOURCE_PATH | tr -d '[:space:]' )

# now starting the backup job
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
if ( ssh -o StrictHostKeyChecking=no $BACKUP_TARGET_HOST "[ -d $BACKUP_TARGET_PATH/$TODAY ]") ; then
    echo "$(date): Backup directory $BACKUP_TARGET_PATH/$TODAY already exists" >> $LOGFILE ;
    echo "$(date): We simply update $BACKUP_TARGET_PATH/$TODAY via rsync" >> $LOGFILE ;
else
    echo "$(date): copying yesterdays backup as a starting point for todays backup" >> $LOGFILE ; 
    ssh -o StrictHostKeyChecking=no $BACKUP_TARGET_HOST "cp -al $BACKUP_TARGET_PATH/latest/. $BACKUP_TARGET_PATH/$TODAY" >> $LOGFILE 2>&1 ;
fi

# now running rsync (without compression!) for every folder on the source host
for i in "${SOURCES[@]}" 
    do 
        echo "$(date): rsyncing $i …" >> $LOGFILE 
        
        # simple switch for either backing up from remote host (if BACKUP_SOURCE_HOST is set) or localhost
        if [ -z "${BACKUP_SOURCE_HOST}" ]
        then
            rsync -a --stats --delete $i $BACKUP_TARGET_HOST:$BACKUP_TARGET_PATH/$TODAY >> $LOGFILE 2>&1
        else 
            ssh -o StrictHostKeyChecking=no $BACKUP_SOURCE_HOST "/opt/bin/rsync -a --stats --delete $i $BACKUP_TARGET_HOST:$BACKUP_TARGET_PATH/$TODAY" >> $LOGFILE 2>&1
        fi
    done

# switch symlink "latest" when operations succeeded
echo "$(date): Switching symbolic link \"latest\" to new backup \"$TODAY\"" >> $LOGFILE
ssh $BACKUP_TARGET_HOST "rm -f $BACKUP_TARGET_PATH/latest" >> $LOGFILE 2>&1
ssh $BACKUP_TARGET_HOST "cd $BACKUP_TARGET_PATH ; ln -s $TODAY latest" >> $LOGFILE 2>&1

# last action:  removing lockfile
rm $LOCKFILE >> $LOGFILE 2>&1

echo "************************************************************" >> $LOGFILE 
echo "$(date): finished creating backup \"$TODAY\"" >> $LOGFILE
echo "************************************************************" >> $LOGFILE
