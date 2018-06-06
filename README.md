# backup-cron
backup service via ssh/rsync

The script is supposed to run once a day and creates a new folder on the remote backup host for every day.
Every new backup is derived from yesterday's backup by setting hard links. Afterwards rsync will update only the changed files (and delete the removed files!)


## Prerequisites
For this to work, we need the following parameters 
to be exported in the environment:

* `BACKUP_TARGET_HOST`
* `BACKUP_TARGET_PATH`
* `BACKUP_SOURCE_PATH`

If `BACKUP_SOURCE_HOST` is given as well,
it will trigger the remote2remote backup.
Otherwise, the default is to back up the  
local data at `BACKUP_SOURCE_PATH`.

Second, you'll need a working SSH connection
(with keyfiles) between localhost and both 
`BACKUP_TARGET_HOST` and `BACKUP_SOURCE_HOST` (if given).
If given, the `BACKUP_SOURCE_HOST` will need to be
able to connect to the `BACKUP_TARGET_HOST`, as well.
All necessary files (keys and config) should be mounted
into the container at `/root/.ssh`.

## Sample Docker Command

```
docker run --rm -it \
  -e "BACKUP_TARGET_HOST=myTargetHost" 
  -e "BACKUP_SOURCE_PATH=/source/to/backup/" 
  -e "BACKUP_TARGET_PATH=/target/path/" 
  -v /path/to/.ssh:/root/.ssh 
  -v /local/path/to/source:/source/to/backup
  edirom/backup-cron
```

