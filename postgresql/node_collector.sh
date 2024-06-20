#!/bin/bash
#######################################################################
# Disclaimer: 
# - Please mask the sensitive info in the file config_*.log
# - The logs of this script will be used by Instaclustr Engineers ONLY 
#######################################################################

# help function to provide an example in case parameter is non-existent
help_function()
{
   echo ""
   echo "Usage: $0 -v version -d database -u username"
   echo "-v    postgreSQL version."
   echo "-d    database name."
   echo "-u    postgreSQL username."
   exit 1 # exit script after printing help
}

# usage function to provide an example of command along with arguments 
usage() 
{
     echo "Usage: $0 -v version -d database -u username" 1>&2; 
     exit 1; 
}

# handle parameters and assign value to parameters
while getopts "v:d:u:" opt
do
case "$opt" in
    v ) VERSION="$OPTARG";;
    d ) DB_NAME="$OPTARG";;
    u ) DB_USER="$OPTARG";;
    ? ) help_function ;; 
esac
done

# verify if parameters are mentioned, otherwise call usage()
if [ -z "${VERSION}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_USER}" ]; then
    usage
fi

# GLOBAL VARIABLES
# change these in case other than default.
PORT=5432 
PGBIN=/usr/local/pgsql/bin 
DATA_PATH=/usr/local/pgsql/data
LOG_PATH=/var/log/postgresql
CONFIG_PATH=/etc/postgresql/$VERSION/main 
PGBACKREST_CONFIG_PATH=/etc/pgbackrest/ #If no file exists in that location then the old default of /etc/pgbackrest

# global 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_DIR=/tmp/PG_InstaCollection_$(date +%Y%m%d%H%M)
FILE_TIMESTAMP=$(date +%Y%m%d%H%M)
IP=$(hostname --ip-address | tr -d [:blank:])

# function to collect system info 
getsystem()
{
    top -cbn 1 > $INFO_DIR/top_$FILE_TIMESTAMP.log
    ps -aux > $INFO_DIR/process_$FILE_TIMESTAMP.log
    vmstat 1 20 > $INFO_DIR/vmstat_$FILE_TIMESTAMP.log
    iostat -x 1 30 > $INFO_DIR/iostat_$FILE_TIMESTAMP.log
    sar > $INFO_DIR/sar_$FILE_TIMESTAMP.log
}

# function to get users info 
getuser()
{
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "\du+;" > $INFO_DIR/users_$FILE_TIMESTAMP.log
}

# function to get activity info 
getactivity()
{
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "select * from pg_stat_activity;" > $INFO_DIR/stat_activity_$FILE_TIMESTAMP.log
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "select count(*) from pg_stat_activity group by state;" > $INFO_DIR/count_$FILE_TIMESTAMP.log
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "select *,relation::regclass from pg_locks;" > $INFO_DIR/lock_$FILE_TIMESTAMP.log
} 

# function to get version info 
getversion()
{
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "SHOW server_version;" > $INFO_DIR/version_$FILE_TIMESTAMP.log; 
}

# function to get configuration info 
getconfig()
{
    # system catalogue view providing a summary of the ccurrent ontents of the server's configuration files. (or TABLE pg_settings; or postgresql.conf)
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "SHOW ALL;" > $INFO_DIR/postgresql_config_$FILE_TIMESTAMP.log 

    # configuration parameter settings as successfully applied at the last configuration reload. (or SELECT * FROM pg_file_settings)
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "TABLE pg_file_settings;" > $INFO_DIR/fileconfig_$FILE_TIMESTAMP.log 

    # configuration settings for host-based authentication (or TABLE pg_hba_file_rules; or pg_hba.conf)
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "SELECT pg_read_file('pg_hba.conf');" > $INFO_DIR/hba_config_$FILE_TIMESTAMP.log 
}

# function to get size info in $DATA_PATH
get_size_info()
{
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "SHOW data_directory;" >> $INFO_DIR/data_dir_$FILE_TIMESTAMP.log
    du -sh $($PGBIN/psql -qAt -p $PORT -U $DB_USER $DB_NAME -c "SHOW data_directory;")/* >> $INFO_DIR/data_dir_$FILE_TIMESTAMP.log
    $PGBIN/psql -p $PORT -U $DB_USER $DB_NAME -c "SELECT pg_database.datname AS dbname, pg_database_size(pg_database.datname)/1024/1024/1024 AS sizegb FROM pg_database ORDER by pg_database_size(pg_database.datname) DESC;" > $INFO_DIR/dbsize_$FILE_TIMESTAMP.log
}

# function to copy all configuration files e.g. pgbackrest.conf
copy_config_files()
{
    config_files=("$PGBACKREST_CONFIG_PATH/pgbackrest.conf")

    for i in "${config_files[@]}"
    do
        cp $i $INFO_DIR
    done
}

# function to copy all log files 
copy_log_files()
{
    local log_files=("$LOG_PATH/*")

    for i in "${log_files[@]}"
    do
            cp $i $INFO_DIR
    done
}

# main function to control to workflow here 
main()
{
    # starts actual script execution and rename if already exsisting directory 
    echo "Creating local directory for data collection $INFO_DIR"
    mv $INFO_DIR $INFO_DIR`date +%Y%m%d%H%M` 2>/dev/null  
    mkdir -p $INFO_DIR

    #start execution to collect required information. please comment/uncomment for enabling the usage of function(s) 
    getsystem &
    #getuser &
    getactivity &
    getversion &
    getconfig &
    #get_size_info &
    #copy_config_files &
    #copy_log_files &

    echo "Waiting for background functions to complete"
    wait

    # compress the required information into directory, compress the file and cleanup
    result_file=/tmp/PG_InstaCollection_$(date +%Y%m%d%H%M).tar.gz
    tar -zcf $result_file -C $INFO_DIR .
    rm -r $INFO_DIR

    echo "Process complete. File generated : " $result_file
}

# run main function
main