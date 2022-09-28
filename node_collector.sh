#!/bin/bash

#The file location values used are for apache Cassandra defaults. 
#Change these in case other than default.
CONFIG_PATH=/etc/cassandra
LOG_PATH=/var/log/cassandra

#List of data directories; if more than one list all with delimiter ','
#e.g. DATA_PATHS=path/to/dir1,path/to/dir2
DATA_PATHS=/var/lib/cassandra/data/data
GC_LOGGING_ENABLED=yes
CASSANDRA_HOME=/var/lib/cassandra
GC_LOG_PATH=${CASSANDRA_HOME}/logs

#Variables to hold data collection and system info.
ip=$(hostname --ip-address | tr -d [:blank:])
data_dir=/tmp/DataCollection_${ip} 
data_file=$data_dir/disk.info
io_stats_file=$data_dir/io_stat.info
cpu_info=$data_dir/cpu.info
mem_info=$data_dir/mem.info
data_file_count=$data_dir/sstable_count.info
block_info=$data_dir/storage_device.info

#Managing Instacollector version
ic_version=2
echo "Instacollector version = ${ic_version}" > $data_dir/ic_version.info


copy_config_files()
{
echo "$ip : Copying files"
local config_files=("$CONFIG_PATH/cassandra.yaml" "$CONFIG_PATH/cassandra-env.sh" "$LOG_PATH/system.log" "$CONFIG_PATH/jvm.options" "$CONFIG_PATH/logback.xml")

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
local commands=("df -h" "du -h")
local paths=($(echo "$DATA_PATHS" | tr ',' '\n'))

for i in "${commands[@]}"
do
    for j in "${paths[@]}"
    do
        echo "" >> $data_file
        k=$(echo $i $j)
        echo "$k" >> $data_file
        eval $k >> $data_file
    done
done
}


get_datafile_count()
{
echo "$ip : Executing sstables count command"
local paths=($(echo "$DATA_PATHS" | tr ',' '\n'))
for j in "${paths[@]}"
do
    find ${j} -maxdepth 3 -type f  | wc -l | xargs -n1 echo "Total sstable count : " >> $data_file_count
    for i in `ls -1 ${j}`;
    do
        find  ${j}/${i} -maxdepth 2 -type f | wc -l | xargs -n1 echo "Keyspace ${i}, Total number of sstables : " >> $data_file_count
    done
done
}

get_block_info()
{
echo "$ip : Executing lsblk command"
lsblk > $block_info
}

get_cpu_info() {
    echo "$ip : Executing /proc/cpuinfo command"
    cat /proc/cpuinfo > $cpu_info
}

get_mem_info() {
    echo "$ip : Executing /proc/meminfo command"
    cat /proc/meminfo > $mem_info
}

get_io_stats()
{
echo "$ip : Executing iostat command"
#Collecting iostat for 60 sec. please change according to requirement
eval timeout -sHUP 60s iostat -x -m -t -y -z 30 < /dev/null > $io_stats_file

}

get_node_tool_info()
{
#The nodetool commands and their respective filenames are on the same index in the arrays 
#the total number of entries in the arrays is used in the for loop.
    
local commands=("nodetool info" "nodetool version" "nodetool status" "nodetool tpstats" "nodetool compactionstats -H" "nodetool gossipinfo" "nodetool cfstats -H" "nodetool ring" "nodetool describecluster")
local filenames=("nodetool_info" "nodetool_version" "nodetool_status" "nodetool_tpstats" "nodetool_compactionstats" "nodetool_gossipinfo" "nodetool_cfstats" "nodetool_ring" "nodetool_describecluster")

echo "$ip : Executing nodetool commands "

for i in {0..8}
do
    local cmd_file=$data_dir/${filenames[i]}.info
    echo "" >> $cmd_file
    eval ${commands[i]} >> $cmd_file
done

}

echo "$ip : Creating local directory for data collection $data_dir"
#rename already exsisting directory 
mv $data_dir $data_dir_`date +%Y%m%d%H%M` 2>/dev/null 
mkdir $data_dir

#start execution 
get_datafile_count &
get_cpu_info &
get_mem_info &
get_io_stats &
copy_config_files &
get_size_info &
get_node_tool_info &
get_block_info &

echo "$ip : Waiting for background functions to complete"
wait

#compress the info directory 
tar -zcf /tmp/InstaCollection.tar.gz -C $data_dir .

echo "$ip : Process Complete."
