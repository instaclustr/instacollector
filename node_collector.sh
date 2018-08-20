#!/bin/bash

#The file location values used are for apache Cassandra defaults. 
#Change these in case other than default.
CONFIG_PATH=/etc/cassandra
LOG_PATH=/var/log/cassandra
DATA_PATH=/var/lib/cassandra/data
GC_LOGGING_ENABLED=yes
CASSANDRA_HOME=/var/lib/cassandra
GC_LOG_PATH=${CASSANDRA_HOME}/logs

#Variables to hold data collection and system info.
ip=$(hostname --ip-address)
data_dir=/tmp/DataCollection_${ip} 
data_file=$data_dir/disk.info
io_stats_file=$data_dir/io_stat.info

copy_config_files()
{
echo "$ip : Copying files"
local config_files=("$CONFIG_PATH/cassandra.yaml" "$CONFIG_PATH/cassandra-env.sh" "$LOG_PATH/system.log" "$CONFIG_PATH/jvm.options")

if [ "$GC_LOGGING_ENABLED" == "yes" ]
then
	config_files+=( "$GC_LOG_PATH/gc.log*" )
fi

for i in "${config_files[@]}"
do
        cp $i $data_dir
done
}

get_size_info()
{
echo "$ip : Executing linux commands"
local commands=("df -h $DATA_PATH" "du -h $DATA_PATH")

for i in "${commands[@]}"
do
        echo "" >> $data_file
        echo "$i" >> $data_file
        eval $i >> $data_file
done
}

get_io_stats()
{
echo "$ip : Executing iostat command"
#Collecting iostat for 60 sec. please change according to requirement
eval timeout -sHUP 60s iostat -x -m -t -y -z 30 < /dev/null > $io_stats_file

}

get_node_tool_info()
{
local commands=("nodetool info" "nodetool version" "nodetool status" "nodetool tpstats" "nodetool compactionstats" "nodetool gossipinfo" "nodetool cfstats" "nodetool ring")

echo "$ip : Executing nodetool commands "

for i in "${commands[@]}"
do
    local cmd_file=$data_dir/"${i// /_}".info
    echo "" >> $cmd_file
    eval $i >> $cmd_file
done

}

echo "$ip : Creating local directory for data collection $data_dir"
#rename already exsisting directory 
mv $data_dir $data_dir_`date +%Y%m%d%H%M` 2>/dev/null 
mkdir $data_dir

#start execution 
get_io_stats &
copy_config_files &
get_size_info &
get_node_tool_info &


echo "$ip : Waiting for background functions to complete"
wait

#compress the info directory 
tar -zcf /tmp/InstaCollection.tar.gz -C $data_dir .

echo "$ip : Process Complete."
