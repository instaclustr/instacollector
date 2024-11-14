#!/bin/bash
#!TODO: implement https://google.github.io/styleguide/shellguide.html
#==========================#
# -- Collection Options -- #
#==========================#
# -- Paths
KAFKA_HOME=/opt/kafka
BROKER_BIN_PATH=${KAFKA_HOME}/bin
BROKER_CONFIG_PATH=${KAFKA_HOME}/config
BROKER_LOG_PATH=${KAFKA_HOME}/logs
BROKER_DATA_PATHS=${KAFKA_HOME}/kafka-logs
ZOOKEEPER_CONFIG=${KAFKA_HOME}/config
ZOOKEEPER_LOG_PATH=${KAFKA_HOME}/logs

# -- Ports
KAFKA_CLIENT_PORT=9092
ZOOKEEPER_CLIENT_PORT=2181

# -- GC Logging
GC_LOGGING_ENABLED=yes
GC_LOG_PATH=${KAFKA_HOME}/logs

# -- Arguments from CLI
unset ip
unset command_config
unset debug
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in

    # IP
    -ip | --ip)
        ip="$2"
        echo "$ip : main               : Using ip=$ip"
        shift
        shift
        ;;

    # Command Config
    -c | --command-config)
        command_config="$2"
        shift
        shift
        ;;
    
    # Debug
    -d | --debug)
    debug=true
    shift
    ;;

    # unknown option
    *)
        if [ -z "$ip" ]; then
            ip=$(hostname -I | tail -n -1 | tr -d [:blank:])
        fi
        echo "$ip : main               : WARN : ignoring unknown argument '$1'"
        shift
        ;;
    esac
done

# -- Calculated Defaults
if [ -z "$ip" ]; then
    ip=$(hostname -I | tail -n -1 | tr -d [:blank:])
fi

if [ -z "$debug" ]; then
    debug=false
fi

if [ -z "$ZOOKEEPER_CONFIG" ]; then
    ZOOKEEPER_CONFIG="$BROKER_CONFIG_PATH"
fi

if [ -z "$ZOOKEEPER_CONFIG" ]; then
    ZOOKEEPER_CONFIG="$BROKER_CONFIG_PATH"
fi

if [ ! -z "$command_config" ] && [ ! -f "$command_config" ]; then
    echo "$ip : main               : FATAL : specified command config not found: $command_config"
    exit
elif [ ! -z "$command_config" ]; then
    echo "$ip : main               : using command-config=$command_config"
fi

# -- Output Paths
data_dir=/tmp/DataCollection_${ip}
data_file=$data_dir/disk.info
io_stats_file=$data_dir/io_stat.info
cpu_info=$data_dir/cpu.info
mem_info=$data_dir/mem.info
missing_files=$data_dir/missing_files.info
data_dir=/tmp/DataCollection_${ip}
data_file=$data_dir/disk.info
io_stats_file=$data_dir/io_stat.info
cpu_info=$data_dir/cpu.info
mem_info=$data_dir/mem.info
missing_files=$data_dir/missing_files.info
file_descriptor=$data_dir/file_descriptor.info
hosts_info=$data_dir/hosts_file.info
output_tar=/tmp/InstaCollection.tar.gz


#==========================#
# --     Functions      -- #
#==========================#
copy_config_files() {
    echo "$ip : ${FUNCNAME[0]}  : Copying files"
    local config_files=(
        "$BROKER_CONFIG_PATH/server.properties"
        "$BROKER_CONFIG_PATH/log4j.properties"
        "$BROKER_LOG_PATH/server.log"
        "$BROKER_LOG_PATH/kafkaServer.out"
        "$BROKER_LOG_PATH/kafka-authorizer.log"
        "$BROKER_LOG_PATH/controller.log"
        "$BROKER_LOG_PATH/state-change.log"
        "$BROKER_JAAS_CONFIG/kafka_server_jaas.conf"
        "$ZOOKEEPER_CONFIG/zookeeper.properties"
        "$ZOOKEEPER_CONFIG/zoo.cfg"
        "$ZOOKEEPER_CONFIG/log4j.properties"
        "$ZOOKEEPER_LOG_PATH/zoo.log"
        "$ZOOKEEPER_JAAS_CONFIG/zookeeper_jaas.conf"
        "$ZOOKEEPER_LOG_PATH/zookeeper.out"
    )
    if [ "$GC_LOGGING_ENABLED" == "yes" ]; then
        config_files+=("$GC_LOG_PATH/kafkaServer-gc.log" "$GC_LOG_PATH/zookeeper-gc.log")
    fi

    for i in "${config_files[@]}"; do
        # - Check if the file exists and copy
        if [[ -f "$i" ]]; then
            cp -nr $i* -t $data_dir

            # - Redact passwords
            #!TODO: move redactions to a list & for loop
            #!TODO: account for server.properties* for redactions
            if [[ "$i" == *"server.properties"* ]]; then
                redact_passwords "$data_dir/server.properties"
            elif [[ "$i" == *"kafka_server_jaas.conf"* ]]; then
                redact_passwords "$data_dir/kafka_server_jaas.conf"
            elif [[ "$i" == *"zookeeper_jaas.conf"* ]]; then
                redact_passwords "$data_dir/zookeeper_jaas.conf"
            elif [[ "$i" == *"server.properties"* ]]; then
                redact_passwords "$data_dir/server.properties"
            fi
        else
            if [ "$debug" = true ]; then
                echo "$ip : ${FUNCNAME[0]}  : DEBUG : File $i not found"
            fi
            echo "$ip : ${FUNCNAME[0]}  : File $i not found" >>$missing_files
        fi
    done
    echo "$ip : ${FUNCNAME[0]}  : Done copying files"
}

redact_passwords() {
    local input_file=$1
    echo "$ip : ${FUNCNAME[0]}   : Redacting passwords from $input_file"
    sed -i.bak -e 's: *password.*$:password ****:g' $input_file
    rm $input_file.bak
}

get_size_info() {
    # - collects size of data directories
    echo "$ip : ${FUNCNAME[0]}      : Executing disk space commands"
    local commands=("df -h" "du -h")
    local paths=($(echo "$BROKER_DATA_PATHS" | tr ',' '\n'))

    if [ -d "$BROKER_DATA_PATHS" ]; then
        for i in "${commands[@]}"; do
            for j in "${paths[@]}"; do
                
                # check if the path exists 
                if [ -d "${paths[@]}" ]; then
                    echo "" >>$data_file
                    k=$(echo $i $j)
                    echo "$k" >>$data_file
                    eval $k >>$data_file
                else
                    echo "$ip : ${FUNCNAME[0]}      : ERROR : PATHNOTFOUND : ${paths[@]}"
                fi
            done
        done
    else
        echo "$ip : ${FUNCNAME[0]}      : ERROR: Directory does not exist: $BROKER_DATA_PATHS"
    fi
    echo "$ip : ${FUNCNAME[0]}      : Done executing disk space commands"
}

get_io_stats() {
    if ! [ -x "$(command -v iostat)" ]; then
        echo "$ip : ${FUNCNAME[0]}       : Executable not found - iostat"
    else
        # - Collects iostat for 60 sec. please change according to requirement
        echo "$ip : ${FUNCNAME[0]}       : Executing iostat command"
        eval timeout -sHUP 60s iostat -x -m -t -y -z 30 </dev/null >$io_stats_file
        echo "$ip : ${FUNCNAME[0]}       : Done executing iostat command"
    fi
}

get_file_descriptor() {
    echo "$ip : ${FUNCNAME[0]}: Getting file descriptor count"
    eval ulimit -n </dev/null >$file_descriptor
    echo "$ip : ${FUNCNAME[0]}: Done getting file descriptor count"
}

get_hosts() {
    echo "$ip : ${FUNCNAME[0]}          : Getting hosts info"
    if [[ -f "/etc/hosts" ]]; then
        echo "$ip : ${FUNCNAME[0]}          : Getting contents of hosts file"
        eval cat /etc/hosts </dev/null >$hosts_info
        echo "$ip : ${FUNCNAME[0]}          : Done getting contents of hosts file"
    else
        echo "$ip : ${FUNCNAME[0]}          : ERROR:  FILENOTFOUND /etc/hosts"
    fi
}

get_cpu_memory() {
    echo "$ip : ${FUNCNAME[0]}     : Getting CPU & Memory info"
    if [[ -f "/proc/cpuinfo" ]]; then
        echo "$ip : ${FUNCNAME[0]}     : Executing cpuinfo command"
        eval cat /proc/cpuinfo </dev/null >$cpu_info
        echo "$ip : ${FUNCNAME[0]}     : Done getting CPU info"
    else
        echo "$ip : ${FUNCNAME[0]}     : ERROR : FILENOTFOUND /proc/cpuinfo"
    fi

    if [[ -f "/proc/meminfo" ]]; then
        echo "$ip : ${FUNCNAME[0]}     : Executing cpuinfo command"
        eval cat /proc/meminfo </dev/null >$mem_info
        echo "$ip : ${FUNCNAME[0]}     : Done getting memory info"
    else
        echo "$ip : ${FUNCNAME[0]}     : ERROR : FILENOTFOUND /proc/meminfo"
    fi
}

get_kafka_cli_info() {
    echo "$ip : ${FUNCNAME[0]} : Executing kafka CLI commands "
    # - List of commands & filenames to save output
    #!TODO: make .sh vs bin less messy
    #!TODO: account for version skew with --zookeeper, etc

    local commands=(
        "$BROKER_BIN_PATH/kafka-topics.sh --version"
        "$BROKER_BIN_PATH/kafka-topics.sh --bootstrap-server $ip:$KAFKA_CLIENT_PORT --describe"
        "$BROKER_BIN_PATH/kafka-broker-api-versions.sh --bootstrap-server $ip:$KAFKA_CLIENT_PORT"
        "$BROKER_BIN_PATH/kafka-consumer-groups.sh --bootstrap-server $ip:$KAFKA_CLIENT_PORT --describe --all-groups --verbose"
    )
    local filenames=(
        "kafka-versions-sh"
        "kafka-topics-describe-sh"
        "kafka-api-versions-sh"
        "consumer-groups-sh"
    )

    local commands_bin=(
        "$BROKER_BIN_PATH/kafka-topics --version"
        "$BROKER_BIN_PATH/kafka-topics --bootstrap-server $ip:$KAFKA_CLIENT_PORT --describe"
        "$BROKER_BIN_PATH/kafka-broker-api-versions --bootstrap-server $ip:$KAFKA_CLIENT_PORT"
        "$BROKER_BIN_PATH/kafka-consumer-groups --bootstrap-server $ip:$KAFKA_CLIENT_PORT --describe --all-groups --verbose"
    )
    local filenames_bin=(
        "kafka-versions-bin"
        "kafka-topics-describe-bin"
        "kafka-api-versions-bin"
        "consumer-groups-bin"
    )
    if [ -f "$BROKER_BIN_PATH/kafka-topics" ]; then
        commands=$commands_bin
        filenames=$filenames_bin
    fi

    arrlen=${#commands[@]}
    arrlen="$((arrlen - 1))"
    for ((i = 0; i <= ${arrlen}; i++)); do
        fname=${commands[i]}
        fname=${fname%% *}

        thiscmd=${commands[i]}
        if [[ -f "$command_config" ]]; then
            thiscmd+="--command-config $command_config"
        fi

        if [[ -f "${fname}" ]]; then
            local cmd_file=$data_dir/${filenames[i]}.info
            if [ "$debug" = true ]; then
                echo "$ip : ${FUNCNAME[0]} : DEBUG: Will execute: [$thiscmd]"
            fi
            echo "" >>$cmd_file
            eval $thiscmd >>$cmd_file
        else
            echo "$ip : ${FUNCNAME[0]} : ERROR : FILENOTFOUND ${fname}"
        fi
    done
    echo "$ip : ${FUNCNAME[0]} : Done executing kafka CLI commands "
}


#==========================#
# --    Collect Data    -- #
#==========================#
echo "$ip : main               : Creating local directory for data collection: $data_dir"
# - rename already exsisting directory
mv $data_dir $data_dir_$(date +%Y%m%d%H%M) 2>/dev/null
mkdir $data_dir

# - start execution
get_io_stats &
copy_config_files &
get_size_info &
get_kafka_cli_info &
get_cpu_memory &
get_file_descriptor &
get_hosts &

echo "$ip : main               : Waiting for collection to complete"
wait
echo "$ip : main               : Collection complete"

# -- Report missing files
if [ "$debug" = true ]; then
    "$ip : main               : ********************** Missing files *********************"
    cat $data_dir/missing_files.info
    echo "$ip : main               : **********************************************************"
fi

# - Compress the info directory
echo "$ip : main               : Compressing results to $output_tar"
tar -zcf $output_tar -C $data_dir .
echo "$ip : main               : Process Complete."
