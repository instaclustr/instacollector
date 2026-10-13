#!/bin/bash


# Get IP address of host
IP=$(hostname -i | tr -d [:blank:])

# The file location values used are for apache ClickHouse defaults.
# Change these in case other than default.
CONFIG_PATH="/etc"
LOG_PATH="/var/log"
CLICKHOUSE_HOME="/var/lib/clickhouse"
KEEPER_HOME="/var/lib/clickhouse-keeper"

#List of data directories; if more than one list all with delimiter ','
#e.g. DATA_PATHS=path/to/dir1,path/to/dir2

DATA_PATHS="$CLICKHOUSE_HOME"clickhouse/data
#Variables to hold data collection and system info.
DATA_DIR=/tmp/DataCollection_${IP}
DATA_FILE=$DATA_DIR/disk.info
IO_STATS_FILE=$DATA_DIR/io_stat.info

TLS_ARGS=""
clickhouse_username=""
clickhouse_password=""
useTLS=""

# check whether clickhouse server or clickhouse-keeper is running
case $(pidof "clickhouse-keeper")  in
  0) isKeeperRunning=0  ;;
  1) isKeeperRunning=1  ;;
  *) isKeeperRunning=0 ;;
esac

case $(pidof "clickhouse-server")  in
  0) isClickHouseRunning=0  ;;
  1) isClickHouseRunning=1  ;;
  *) isClickHouseRunning=0 ;;
esac

CLICKHOUSE_CLIENT=$(which clickhouse-client)
CLICKHOUSE_KEEPER=$(which clickhouse-keeper)

check_for_clickhouse()
{
  # what is running

if [[ "$CLICKHOUSE_CLIENT" -eq 0 && "$CLICKHOUSE_KEEPER" -eq 0 ]]; then
  echo "$IP: ${FUNCNAME[0]}: ClickHouse path not found.  Exiting"
  exit 1
fi

if [[  "$isClickHouseRunning" -eq 0   &&   "$isKeeperRunning" -eq 0  ]]; then
  echo "$IP: ${FUNCNAME[0]}: ClickHouse Not Running. Exiting"
  exit 1
fi
}

get_clickhouse_bin_path()
{
  # Get ClickHouse Path
   eval CLICKHOUSE=$(which clickhouse)
    if [ -z "CLICKHOUSE" ]; then
    echo "$IP: ${FUNCNAME[0]}: ClickHouse path not found.  Exiting"
    else
    echo "$IP: ${FUNCNAME[0]}: Found ClickHouse Path $CLICKHOUSE"
    fi
}


copy_config_files()
{
    echo "$IP :  ${FUNCNAME[0]}: Copying configuration files"
    [[ -d "$CONFIG_PATH/clickhouse-server" ]] &&  cp -r  "$CONFIG_PATH"/clickhouse-server/*.*  "$DATA_DIR/server/"
    [[ -d "$CONFIG_PATH/clickhouse-keeper" ]] &&   cp -r  "$CONFIG_PATH"/clickhouse-keeper/*.*  "$DATA_DIR/keeper/"
    echo "$IP :  ${FUNCNAME[0]}: Done copying configuration files"
}

copy_log_files()
{
    if [[ -d "$LOG_PATH/clickhouse-server" ]] ; then
      echo "$IP: ${FUNCNAME[0]}: Copying Server log files"
      cp -r  "$LOG_PATH/clickhouse-server/clickhouse-server.err.log"   "$DATA_DIR/server/clickhouse-server.err.log"
      cp -r  "$LOG_PATH/clickhouse-server/clickhouse-server.log"       "$DATA_DIR/server/clickhouse-server.log"
       echo "$IP: ${FUNCNAME[0]}: Done copying Server log files"
    fi

    if [[ -d "$LOG_PATH/clickhouse-keeper" ]]; then
      echo "$IP :  ${FUNCNAME[0]}: Copying Keeper log files"
      cp -r  "$LOG_PATH/clickhouse-keeper/clickhouse-keeper.err.log"   "$DATA_DIR/keeper/clickhouse-keeper.err.log"
      cp -r  "$LOG_PATH/clickhouse-keeper/clickhouse-keeper.log"       "$DATA_DIR/keeper/clickhouse-keeper.log"
      echo "$IP :  ${FUNCNAME[0]}: Done copying Keeper log files"
    fi
    }

get_file_descriptor() {
    echo "$IP : ${FUNCNAME[0]}: Getting file descriptor count"
    eval ulimit -a  </dev/null > "$DATA_DIR"/file_desriptor.info
    echo "$IP : ${FUNCNAME[0]}: Done getting file descriptor count"
}

get_hosts() {
    echo "$IP : ${FUNCNAME[0]}          : Getting hosts info"
    if [[ -f "/etc/hosts" ]]; then
        echo "$IP : ${FUNCNAME[0]}          : Getting contents of hosts file"
        eval cat /etc/hosts </dev/null      > $DATA_DIR/hosts.info
        echo "$IP : ${FUNCNAME[0]}          : Done getting contents of hosts file"
    else
        echo "$IP : ${FUNCNAME[0]}          : ERROR:  FILENOTFOUND /etc/hosts"
    fi
}

get_cpu_memory() {
    echo "$IP : ${FUNCNAME[0]}     : Getting CPU & Memory info"
    if [[ -f "/proc/cpuinfo" ]]; then
        echo "$IP : ${FUNCNAME[0]}     : Executing cpuinfo command"
        eval cat /proc/cpuinfo </dev/null > "$DATA_DIR"/cpu.info
        echo "$IP : ${FUNCNAME[0]}     : Done getting CPU info"
    else
        echo "$IP : ${FUNCNAME[0]}     : ERROR : FILENOTFOUND /proc/cpuinfo"
    fi

    if [[ -f "/proc/meminfo" ]]; then
        echo "$IP : ${FUNCNAME[0]}     : Executing cpuinfo command"
        eval cat /proc/meminfo </dev/null > "$DATA_DIR"/memory.info
        echo "$IP : ${FUNCNAME[0]}     : Done getting memory info"
    else
        echo "$IP : ${FUNCNAME[0]}     : ERROR : FILENOTFOUND /proc/meminfo"
    fi
}
get_system_info()
{

   echo "$IP :  ${FUNCNAME[0]}: Executing sysctl -a  command"
   eval sysctl -a > "$DATA_DIR"/sysctl.info
   echo "$IP :  ${FUNCNAME[0]}: Done executing sysctl -a  command"
}
get_size_info()
{
    echo "$IP : ${FUNCNAME[0]}: Executing df / du  commands"
    local commands=("df -h" "du -haL")
    local paths=($(echo "$HOME_PATH" | tr ',' '\n'))

    for i in "${commands[@]}"
    do
        for j in "${paths[@]}"
        do
        echo "" >> $DATA_FILE
        k=$(echo $i $j)
        echo "$k" >> $DATA_FILE
        eval $k >> $DATA_FILE
        done
    done
     echo "$IP : ${FUNCNAME[0]}: Done executing df / du  commands"
}

get_io_stats()
{
   local iostat_exists=$(which iostat)
   if [ -z "$iostat_exists" ]; then
   echo " $IP: ${FUNCNAME[0]}:iostat not found. Skipping"
     return
  else
    echo "$IP : ${FUNCNAME[0]}: Executing iostat command"
  fi
    #Collecting iostat for 60 sec. please change according to requirement
    eval timeout -sHUP 60s iostat -mcdtz 30 < /dev/null > $IO_STATS_FILE

}

get_metrics () # Parameters: username, password
{
     # return if not a clickhouse server
      echo "Is this a server?: $isClickHouseServer"
     [[  "$isClickHouseServer"  -eq 0  ]] && return

    # Handles parameters
    echo "$IP : Gathering Cluster Metrics"

    clickhouse_args=""
    if ! [[ -z "${clickhouse_username}" && -z "${clickhouse_password}" ]];
    then
        clickhouse_args="--user $clickhouse_username --password $clickhouse_password"
    fi
# add queries here
    local query=()
    local query+=("SELECT * FROM system.tables WHERE lower(database) NOT IN ('system', 'information_schema')  FORMAT CSVWithNames;")
    local query+=("SELECT * FROM system.tables WHERE lower(database) = 'system' FORMAT CSVWithNames")
    local query+=("SELECT * FROM   system.mutations WHERE (create_time  >= (now() - toIntervalDay(14)))  FORMAT CSVWithNames")
    local query+=("SELECT * FROM   system.errors WHERE last_error_time >= (now() - toIntervalDay(14)) FORMAT CSVWithNames")
    local query+=("SELECT * from system.error_log  WHERE event_date >= (now() - toIntervalDay(14)) FORMAT CSVWithNames")
    local query+=("SELECT * from system.metric_log  FORMAT CSVWithNames")
    local query+=("SELECT * FROM system.asynchronous_metric_log WHERE event_date >= (now() - toIntervalDay(14)) FORMAT CSVWithNames")
    local query+=("SELECT * FROM system.server_settings FORMAT CSVWithNames ")
    local query+=("SELECT * FROM system.query_metric_log FORMAT CSVWithNames ")
    local query+=("SELECT * FROM system.parts FORMAT CSVWithNames")
    local query+=("SELECT * FROM system.part_log  WHERE event_date >= (now() - toIntervalDay(14))  FORMAT CSVWithNames")
    ## query+=("SELECT * FROM system.trace_log  WHERE event_date >= (now() - toIntervalDay(30))  FORMAT CSVWithNames ;")
    ## local  query+=("SELECT * FROM system.text_log WHERE last_error_time >= (now() - toIntervalDay(30)) FORMAT CSVWithNames ;")

# add a table and filename for each query you add
    local tables=()
    local filenames=()
    local tables+=("system.tables" "system.tables" "system.mutations" "system.errors" "system.error_log" "system.metric_log"   "system.asynchronous_metric_log" "system.server_settings" "system.query_metric_log")
    local tables+=("system.parts" "system.part_log")
    local filenames+=("user_tables" "system_tables" "mutations" "errors" "error_log" "metric_log"   "asynchronous_metric_log" "server_settings" "query_metric_log" "parts" "part_log")
    local arraylength=${#filenames[@]}

    for (( i=0; i<${arraylength}; i++ ));
    do
        local cmd_file=$DATA_DIR/${filenames[i]}.csv
        #echo "" >> $cmd_file
         local query="${query[i]}"
         echo "$IP : ${FUNCNAME[0]}: Executing query=$query"
         ${CLICKHOUSE_CLIENT} --query="${query}" -d system "$clickhouse_args" "$TLS_ARGS"  >> "$cmd_file"
    done
}

get_cluster_info() # Parameters: username, password, useTLS
{
   # return if not a clickhouse server
      [[  "$isClickHouseServer"  -eq 0  ]] && return


    # Handles parameters
    clickhouse_args=""
    if ! [[ -z "${clickhouse_username}" && -z "${clickhouse_password}" ]];
    then
        clickhouse_args="--user $clickhouse_username --password $clickhouse_password"
    fi

echo "$IP : Gathering Cluster Information"

local query=()
local query+=("SELECT * from system.build_options FORMAT VERTICAL ")
local query+=("SELECT * FROM system.clusters FORMAT VERTICAL")
local query+=("SELECT * FROM system.replicas FORMAT VERTICAL;")
local query+=("SELECT * FROM system.disks FORMAT VERTICAL")
local query+=("SELECT * FROM system.databases  FORMAT VERTICAL")
local query+=("SELECT * from system.dictionaries  FORMAT VERTICAL")
local query+=("SELECT * FROM system.server_settings WHERE changed FORMAT VERTICAL")
local query+=("SELECT * FROM system.zookeeper_connection  FORMAT VERTICAL")
local query+=("SELECT * FROM system.backups LIMIT 10  FORMAT VERTICAL")
local query+=("SELECT * FROM system.quotas;")

local filenames=()
local filenames+=("build_options" "clusters" "replicas" )
local filenames+=("ch_disk" "databases" "dictionaries"  "server_settings" "zookeeper_connection" )
local filenames+=("backups" "quotas")

local arraylength=${#filenames[@]}

    for (( i=0; i<${arraylength}; i++ ));
    do
        local cmd_file=$DATA_DIR/${filenames[i]}.info
        local query="${query[i]}"
        echo "$IP : ${FUNCNAME[0]}: Executing query=${query}}"
        ${CLICKHOUSE-CLIENT}  --query="${query}" -d system  "$clickhouse_args" "$TLS_ARGS"   > "$cmd_file"
    done


}


help_function()
{
   echo ""
   echo "Usage: $0"
   echo "Usage: $0 -u username -p password"
   exit 1 # Exit script after printing help
}

# Handles parameters
while getopts "u:p:t:" opt
do
case "$opt" in
    u ) clickhouse_username="$OPTARG" ;;
    p ) clickhouse_password="$OPTARG" ;;
    t ) useTLS="$OPTARG" ;;
    ? ) help_function ;; # Print help_function in case parameter is non-existent
esac
done

# Starts actual script execution
echo "$IP : Data Collection Starts. $(date)"
echo "$IP : Creating local directory for data collection $DATA_DIR"
#rename already existing directory
mv $DATA_DIR $DATA_DIR_`date +%Y%m%d%H%M` 2>/dev/null
mkdir -p  $DATA_DIR/server
mkdir -p  $DATA_DIR/keeper


#start execution
check_for_clickhouse &
get_hosts &
get_file_descriptor &
get_size_info &
get_io_stats &
copy_config_files &
copy_log_files &
get_size_info &
get_system_info &
get_cpu_memory

echo "Is this a clickhouse server $isClickHouseServer or Keeper $isClickHouseKeeper"
# CLICKHOUSE SERVER MUST BE RUNNIUNG AND THE CLICKHOUSE CLIENT FOUND
if [[  "$isClickHouseRunning"  && "$CLICKHOUSE-CLIENT"] ; then
  get_cluster_info $clickhouse_username $clickhouse_password &
  get_metrics $clickhouse_username $clickhouse_password
fi

echo "$IP : Waiting for background functions to complete"
wait

#compress the info directory 
tar -zcf /tmp/InstaCollection.tar.gz -C $DATA_DIR .

echo "$IP : Data Collection Complete. $(date)"
