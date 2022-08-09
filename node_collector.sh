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

get_io_stats()
{
    echo "$ip : Executing iostat command"
    #Collecting iostat for 60 sec. please change according to requirement
    eval timeout -sHUP 60s iostat -x -m -t -y -z 30 < /dev/null > $io_stats_file

}

get_nodetool() # Prameters: username, password
{
    # Handles parameters
    nodetool_args=""
    if ! [[ -z "${parameter_username}" && -z "${parameter_password}" ]];
    then
        nodetool_args="-u $parameter_username -pw $parameter_password"
    fi

    #The nodetool commands and their respective filenames are on the same index in the arrays 
    #the total number of entries in the arrays is used in the for loop.
        
    local commands=("nodetool ${nodetool_args} describecluster" "nodetool ${nodetool_args} info" "nodetool ${nodetool_args} version" "nodetool ${nodetool_args} status" "nodetool ${nodetool_args} tpstats" "nodetool ${nodetool_args} compactionstats -H" "nodetool ${nodetool_args} gossipinfo" "nodetool ${nodetool_args} cfstats -H" "nodetool ${nodetool_args} ring")
    local filenames=("nodetool_describecluster" "nodetool_info" "nodetool_version" "nodetool_status" "nodetool_tpstats" "nodetool_compactionstats" "nodetool_gossipinfo" "nodetool_cfstats" "nodetool_ring")

    echo "$ip : Executing nodetool commands "

    for i in {0..8}
    do
        local cmd_file=$data_dir/${filenames[i]}.info
        echo "" >> $cmd_file
        eval ${commands[i]} >> $cmd_file
    done

}

get_nodetool_tablehistograms() # Prameters: username, password
{
    # Handles parameters
    nodetool_args=""
    if ! [[ -z "${parameter_username}" && -z "${parameter_password}" ]];
    then
        cqlsh_args="-u $parameter_username -p $parameter_password"
        nodetool_args="-u $parameter_username -pw $parameter_password"
    fi
 
    local cmd_file="${data_dir}/nodetool_tablehistograms.info"
    echo "" >> $cmd_file

    # Fetch all the keyspaces
    cqlsh_keyspace_arr=($(cqlsh $(hostname -i) ${cqlsh_args} -e "DESC KEYSPACES;"))
    cqlsh_keyspace_arr=("${cqlsh_keyspace_arr[@]//$'\n'/}")
    for i in "${cqlsh_keyspace_arr[@]}"
    do
        # Fetch all the tables
        cqlsh_tables_arr=($(cqlsh $(hostname -i) ${cqlsh_args} -e "USE ${i}; DESC TABLES;"))
        cqlsh_tables_arr=("${cqlsh_tables_arr[@]//$'\n'/}")
        for j in "${cqlsh_tables_arr[@]}"
        do
            eval "nodetool ${nodetool_args} tablehistograms ${i} ${j}" >> "$cmd_file" 2> /dev/null
        done

        unset cqlsh_tables_arr

    done
}


help_function()
{
   echo ""
   echo "Usage: $0"
   echo "Usage: $0 -u username -p password"
   echo -e "\t-u    Remote JMX agent username."
   echo -e "\t-p    Password."
   exit 1 # Exit script after printing help
}

# Handles parameters
while getopts "u:p:" opt
do
case "$opt" in
    u ) parameter_username="$OPTARG" ;;
    p ) parameter_password="$OPTARG" ;;
    ? ) help_function ;; # Print help_function in case parameter is non-existent
esac
done

# Starts actual script execution
echo "$ip : Creating local directory for data collection $data_dir"
#rename already exsisting directory 
mv $data_dir $data_dir_`date +%Y%m%d%H%M` 2>/dev/null 
mkdir $data_dir

#start execution 
get_io_stats &
copy_config_files &
get_size_info &
get_nodetool $parameter_username $parameter_password &
get_nodetool_tablehistograms $parameter_username $parameter_password &

echo "$ip : Waiting for background functions to complete"
wait

#compress the info directory 
tar -zcf /tmp/InstaCollection.tar.gz -C $data_dir .

echo "$ip : Process Complete."
