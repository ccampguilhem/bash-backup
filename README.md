# Simple bash backup solution

This is a very simple solution I use for my incremental backups on my computer.

The script can be run with the following command:

```bash
sudo backup.bash --daily --content *backup_list* *destination*
```

`--daily` specifies the type of backup and can be replaced with `--weekly` or 
`--monthly`. 

*destination* is the destination folder where the backup is done.

*backup_list* is the input file listing all directories and files to be backed 
up.

It is best to run the script with crontab:

```bash
# Crontab configuration
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  *  user command to be executed
#
0 1 * * * /path/to/script/backup.bash --daily --content /path/to/list/backup/backup.list /destination >> /destination/backup.log
0 3 * * 0 /path/to/script/backup.bash --weekly --content /path/to/list/backup.list /destination >> /destination/backup.log
0 5 1 * * /path/to/script/backup.bash --monthly --content /path/to/list/backup.list /destination >> /destination/backup.log
0 5 2 9 * /path/to/script/backup.bash --yearly --content /path/to/list/backup.list /destination >> /destination/backup.log
```

In this example, daily backup is done every day at 1am, weekly backup is done 
every Sunday at 3am and montly backup is done first day of the month at 5am.

You can configure the following variables in the script:

```bash
MAX_DAILY_BACKUPS=7
MAX_WEEKLY_BACKUPS=5
MAX_MONTHLY_BACKUPS=6
MAX_YEARLY_BACKUPS=5
```

The variables configure how many backup are kept for each kind of backup. In 
the example above, the last 7 days, the last 5 weeks and the five 6 months are 
stored. It means that doing a backup on the 8th day will remove from the 
backup directory the first daily backup and so on and so forth for weekly and 
monthly upgrades.

How it works ?

In the examples below we suppose that `/destination` was specified as the 
destination backup.

At each daily backup, the `/destinatation/daily` is updated with a `rsync`.
Then, a hardlink is created from this folder to a folder with a timestamp, 
for example: `2020-05-04_01:00:01_daily`

When a weekly backup is done, the latest daily backup is hardlinked to a 
destination folder with a timestam, for example: `2020-05-10_03:00:01_weekly`.

Finally, when a monthly backup is done, the latest weekly backup is hardlined 
to a destination folder with a timestamp, for example: 
`2020-05-01_05:00:01_monthly`

In addition, each kind of backup ensures that a maximum number of folders are 
stored as configured by `MAX_DAILY_BACKUPS`, `MAX_WEEKLY_BACKUPS` and 
`MAX_MONTHLY_BACKUPS`.

The backup list file is expected to have the following format:

```
/first/path/to/backup
/file/to/backup/file.txt
/another/path/with/exclude pattern1,pattern2
```

It is possible to provide exclude patterns to not backup files and directories 
with the given pattern. You can use wild-character such as *. For example:

```
/files *.gz tmp
```

Will recursively backup every files and directories from `/files` as long as 
files does not have `.gz` extension and files are in `tmp` subdirectories. If 
you need to provide multiple patterns, separate each pattern with a coma `,` 
character.

I would recommand to back up the list of files to be backed up as well.

You can save the crontab actions in a file `backup.crontab`. You can then update the crontab list by doing:

```
crontab backup.crontab
```

Any instruction not already present will be added to the list.


