#!/bin/bash

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
# 0 1 * * * /home/opt/backup/backup.bash --daily --content /home/opt/backup/backup.list /external/backup/kango-linux >> /home/opt/backup/backup.log
# 0 3 * * 0 /home/opt/backup/backup.bash --weekly --content /home/opt/backup/backup.list /external/backup/kango-linux >> /home/opt/backup/backup.log
# 0 5 1 * * /home/opt/backup/backup.bash --monthly --content /home/opt/backup/backup.list /external/backup/kango-linux >> /home/opt/backup/backup.log
#
# To force a manual run
# sudo /home/opt/backup/backup.bash --daily --content /home/opt/backup/backup.list /external/backup/kango-linux

# Initialisation
MODE="daily"
BACKUP_ROOT_DIR=""
CONTENT=""
ARGS=("$@")
MAX_DAILY_BACKUPS=7
MAX_WEEKLY_BACKUPS=5
MAX_MONTHLY_BACKUPS=6

# Termination function
function terminate(){
    echo "End of backup session: $(date +'%Y-%m-%d %H:%M:%S')"
    exit $1
}

# Error function
function check_errors(){
    error_code=$1
    if [ ${error_code} -ne 0 ]; then
        echo "Backup session terminated with error code: ${error_code}"
        terminate ${error_code}
    fi
}

# Command line arguments
function command_line(){
    i=0
    while true
    do
        arg=${ARGS[${i}]}
        if [ -z ${arg} ]
        then
            break
        else
            if [ ${arg} == "--daily" ]; then
                MODE="daily"
            elif [ ${arg} == "--weekly" ]; then
                MODE="weekly"
            elif [ ${arg} == "--monthly" ]; then
                MODE="monthly"
            elif [ ${arg} == "--content" ]; then
                let i++
                CONTENT=${ARGS[${i}]}
            else
                BACKUP_ROOT_DIR=${arg}
            fi
            let i++
        fi
    done

    # Check command line arguments
    if [ -z ${BACKUP_ROOT_DIR} ]
    then
        echo "Error: BACKUP_ROOT_DIR has to be specified."
        return 101
    fi
    if [ -z ${CONTENT} ]
    then
        echo "Error: CONTENT has to be specified."
        return 102
    fi
}

# Purging old backups
function purging_backup(){
    pattern=$1
    max_backups=$2
    for backup in `ls -d ${pattern}`
    do
        found=0
        for latest_backup in `ls -d ${pattern} | tail -${max_backups}`
        do
            if [ ${backup} == ${latest_backup} ]; then
                found=1
                break
            fi
        done
        if [ ${found} -eq 0 ]; then
            echo -n "Purging old backup ${backup}... "
            start_time=$(date +%s)
            rm -rf ${backup}
            end_time=$(date +%s)
            echo "done ($(($end_time - $start_time)) sec)"
        fi
    done    
}

# Daily backup
function daily_backup(){
    # Initialisations
    echo "Starting a daily backup in ${BACKUP_DAILY_DIR}..."
    nb_errors=0
    
    # Make sure that backup folder exists
    mkdir -p ${BACKUP_DAILY_DIR} 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: cannot create ${BACKUP_DAILY_DIR}."
        return 201
    fi
    
    # Run rsync for each content
    while IFS= read -r line
    do
        IFS=' ' read -ra fields <<< "$line"
        IFS=',' read -ra exclude_patterns <<< "${fields[1]}"
        exclude=""
        i=0
        while true
        do
            pattern=${exclude_patterns[$i]}
            if [ -z ${pattern} ];then
                break
            else
                exclude="${exclude} --exclude ${pattern}"
                let i++
            fi
        done
        path=${fields[0]}
        if [ ! -z ${path} ]; then
            start_time=$(date +%s)
            rsync_command="rsync -aR --delete --delete-excluded ${exclude} ${path} ${BACKUP_DAILY_DIR}"
            echo -n "Backup of ${path}... "
            ${rsync_command}
            end_time=$(date +%s)
            if [ $? -ne 0 ]; then
                echo "error"
                let nb_errors++
            else
                echo "ok ($(($end_time - $start_time)) sec)"
            fi
        fi
    done < "$CONTENT"
    
    # Making a hardlink copy of current status of backup
    echo -n "Hard-linking daily backup... "
    start_time=$(date +%s)
    cp -al ${BACKUP_DAILY_DIR} ${BACKUP_DAILY_DIR_NOW}
    end_time=$(date +%s)
    echo "done ($(($end_time - $start_time)) sec)"
    
    # Only keep MAX_DAILY_BACKUPS
    purging_backup "${BACKUP_ROOT_DIR}/*_daily" ${MAX_DAILY_BACKUPS}
    
    # End of backup    
    if [ $nb_errors -ne 0 ]; then
        echo "Error: ${nb_errors} error(s) occured while running rsync."
        return 202
    else
        echo "Daily backup successful."
    fi
}

# Weekly backup
function weekly_backup(){
    # Initialisations
    echo "Starting a weekly backup in ${BACKUP_WEEKLY_DIR_NOW}..."
    
    # Copy the latest daily backup
    latest_backup=`ls -d ${BACKUP_ROOT_DIR}/*_daily | tail -1`
    echo -n "Hard-linking daily backup... "
    start_time=$(date +%s)
    cp -al ${latest_backup} ${BACKUP_WEEKLY_DIR_NOW}
    end_time=$(date +%s)
    echo "done ($(($end_time - $start_time)) sec)"
    
    # Only keep MAX_WEEKLY_BACKUPS
    purging_backup "${BACKUP_ROOT_DIR}/*_weekly" ${MAX_WEEKLY_BACKUPS}
    
    # End of backup
    echo "Weekly backup successful."
}

# Montly backup
function montly_backup(){
    # Initialisations
    echo "Starting a monthly backup in ${BACKUP_MONTHLY_DIR_NOW}..."
    
    # Copy the latest weekly backup
    latest_backup=`ls -d ${BACKUP_ROOT_DIR}/*_weekly | tail -1`
    echo -n "Hard-linking weekly backup... "
    start_time=$(date +%s)
    cp -al ${latest_backup} ${BACKUP_MONTHLY_DIR_NOW}
    end_time=$(date +%s)
    echo "done ($(($end_time - $start_time)) sec)"
    
    # Only keep MAX_MONTHLY_BACKUPS
    purging_backup "${BACKUP_ROOT_DIR}/*_monthly" ${MAX_MONTHLY_BACKUPS}
    
    # End of backup
    echo "Monthly backup successful."
}

# Main program
function main(){
    # Intialisation
    echo "----------------------------------------"
    TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
    echo "Backup session $(date +'%Y-%m-%d %H:%M:%S')"

    # Read command line arguments
    command_line
    check_errors $?   
    
    # Configuration
    BACKUP_DAILY_DIR=${BACKUP_ROOT_DIR}/daily
    BACKUP_DAILY_DIR_NOW=${BACKUP_ROOT_DIR}/${TIMESTAMP}_daily
    BACKUP_WEEKLY_DIR_NOW=${BACKUP_ROOT_DIR}/${TIMESTAMP}_weekly
    BACKUP_MONTHLY_DIR_NOW=${BACKUP_ROOT_DIR}/${TIMESTAMP}_monthly

    # Do backup
    if [ ${MODE} == "daily" ]; then
        daily_backup
    elif [ ${MODE} == "weekly" ]; then
        weekly_backup
    elif [ ${MODE} == "monthly" ]; then
        montly_backup    
    fi
    check_errors $?
    
    # Normal termination
    terminate 0
}

main

