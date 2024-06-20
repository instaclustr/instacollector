#!/bin/bash
# ---------------------------------------------------------------------------------#----------------------------------- #
# Instacollector_Redis - A Redis node metrics and log collector for Redis clusters #                                    #
# ---------------------------------------------------------------------------------#                                    #
#                                                                                                                       #
# Instacollector_Redis is an interactive command-line metrics collection tool for open source Redis clusters. It is     #
# designed to gather diagnostic information to help review a cluster's state. As the script is interactive, input       #
# parameters are not required. Options have been provided to collect metrics from the Redis nodes(via ssh) or cluster   #
# stats(via redis-cli) or both(recommended).                                                                            #
#                                                                                                                       #
# For collecting node level metrics and conf/log files, the localhost should have ssh-private key access to all the     #
# nodes in the Redis cluster. It is recommended for the ssh user to have password-less sudo access on the Redis nodes   #
# to be able to collect all the required metrics. If sudo access is not available, you can still attempt collection as  #
# the ssh user but we may get truncated data on some metrics. Please ensure that the ssh user has access to read the    #
# Redis working directory and files in-order to be able to collect the required data. The /tmp directory will be used   #
# on the Redis nodes for metrics collection. Please ensure that the /tmp directory is writable and has enough disk      #  
# space on all the Redis nodes(~150KB each).                                                                            #
#                                                                                                                       #
# For gathering cluster stats, the localhost should have redis-cli installed and setup on the system-wide PATH. If you  #
# don't already have redis-cli, please ensure that you install the latest version. Only redis-cli versions 6 and above  #
# have TLS support. Instructions for installation: https://redis.io/docs/getting-started/installation/                  #
# The redis-cli client will be used to directly gather live metrics from the Redis cluster. Hence, please ensure that   #
# the localhost has access to connect to the Redis cluster's client port(default: 6379). If TLS/SSL is enabled on Redis,# 
# please ensure that the required Redis client certificate and key along with the CA certificate are locally available. #
#                                                                                                                       #
# Instacollector_Redis gets the the Redis cluster connection information from the redis_cluster_nodes.list file in      #
# the same directory. Please enter the IP/DNS of all the nodes in your Redis cluster in redis_cluster_nodes.list        #
# before attempting a run. The file should only contain a list of either the IP or DNS of each node in the Redis        #
# cluster and each IP/DNS should be on a separate line. Please refer to the file format of redis_cluster_nodes.list     #
# which is available in the same directory of the git repo as an example. Please remove the existing IPs on it and add  #
# the ones for you Redis cluster nodes.                                                                                 #
#                                                                                                                       #
# Once all the required information is provided to Instacollector_Redis, it will attempt to connect and acquire the     #
# required metrics from the Redis cluster.                                                                              #
#                                                                                                                       #
# The Redis cluster's node metrics, conf/logs and stats are packaged into a tarball for easy consumption in the /tmp    #
# directory of the localhost. Please ensure that /tmp directory is writable and has enough disk-space on the localhost. #
# Ex: For a fresh 6 node cluster the uncompressed space required would be around 1 MB on the localhost.                 # 
#                                                                                                                       #
# --------------------------------------------------------------------------------------------------------------------- #

# Temp directory for gathering metrics 
TEMP_DIR="/tmp/instaredis_$(date +%Y_%m_%d_%H%M)"


# User exit option 
exit_user() {
    echo
    echo "Exiting Instacollector_Redis as per user request"
    echo
    exit 0
}


# Invalid user choice 
invalid_choice() {
    echo >&2
    echo "Invalid entry. Please enter 1 for YES or 2 for NO or 3 to EXIT" >&2
    echo >&2
}


# Setup temp directory for gathering metrics 
create_dir(){
    if mkdir -p "${TEMP_DIR}/${1}"
        then
            echo "Temp directory ${TEMP_DIR}/${1} created successfully on local host" 
        else
            echo "Unable to create required Temp directory ${TEMP_DIR}/${1} on local host" >&2
            echo "Please ensure $USER has write access to /tmp directory on local host and try again" >&2
            exit 2
    fi
}


# Validate ssh credentials and setup remote tmp dir for node metrics
create_remote_dir() {
    SSH_PIDS=()
    SSH_HOSTS=()
    HOST_COUNT=0
    echo "Validating ssh credentials and setting up required Temp directory $1 on all Redis cluster nodes."
    while read HOST
        do 
            ((HOST_COUNT++))
            TEMP_NODE_DIR="${1}/node${HOST_COUNT}_${HOST}"
            ssh -o "StrictHostKeyChecking no" -q -n -i $PRIVATE_KEY ${HOST_USER}@${HOST} "mkdir -p $TEMP_NODE_DIR" &
            SSH_PIDS+=("$!")
            SSH_HOSTS+=("$HOST")
            
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)
    
    for((i=0;i<HOST_COUNT;i++))
        do
            if wait ${SSH_PIDS[${i}]} &> /dev/null
                then
                    true
                else
                    echo "Unable to create required Temp directory $1 on ${SSH_HOSTS[${i}]}" >&2
                    echo "Please verify ssh credentials/password-less sudo access" >&2
                    echo "Verify network connectivity to node ${SSH_HOSTS[${i}]} and ensure it has enough disk space on /tmp with write access." >&2
                    exit 21
            fi
        done
}




# Print format
print_selection() {
    echo
    echo "$1"
    echo
}


# Check ssh key
check_ssh_key() {
    
    if ssh-keygen -lf "${1}" &> /dev/null
        then
            if grep PRIVATE "${1}" &> /dev/null
                then
                    true
                else
                    printf '\n%s\n\n' "${1} is not a PRIVATE key file. Please ensure that you have the correct key file and try again." >&2
                    exit 3
            fi
        else
            printf '\n%s\n\n' "Invalid key file or unable to access ${1}. Please check and try again by entering the full path to the file." >&2
            exit 3
    fi
}


# TLS certificate checker
check_tls_cert() {
    if [[ -s ${1} ]] && [[ -r ${1} ]]
        then
            if openssl x509 -noout -in ${1} &> /dev/null
                then
                    true
                else
                    printf '\n%s\n\n' "${1} is not a valid certificate file. Please check and try again." >&2
                    exit 33
            fi
        else
            printf '\n%s\n\n' "Invalid certificate file or Unable to access ${1}. Please check and try again by entering the full path to the file." >&2
            exit 33
    fi
}


get_pass() {
    unset REDIS_TEMP_PASS
    PROMPT="$1"
    while IFS= read -p "$PROMPT" -r -s -n 1 CHAR 
    do
        if [[ $CHAR == $'\0' ]]
            then
                break
        fi
        if [[ $CHAR == $'\177' ]]
            then
                PROMPT=$'\b \b'
                REDIS_TEMP_PASS="${REDIS_TEMP_PASS%?}"
            else
                PROMPT='*'
                REDIS_TEMP_PASS+="$CHAR"
        fi
    done
    printf '\n' >&2
    echo $REDIS_TEMP_PASS
}


# Check remote path provided for redis nodes
check_redispath() {
    while read HOST
        do
            if ssh -o "StrictHostKeyChecking no" -q -n -i $PRIVATE_KEY ${HOST_USER}@${HOST} "${SUDO} test -r $1"
                then
                    echo "Path verified on a cluster node"
                    break
                else
                    printf '\n%s\n\n' "Unable to access $1 on the redis node ${HOST}" >&2
                    printf '\n%s\n\n' "Please check path/ssh user access to $1 and try again by entering the full path." >&2
                    exit 41
            fi
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)

}

node_transfer() {
    echo
    echo "Starting transfer of $3 data from Redis nodes..."
    echo
    local NODE_COUNT=0
    local NODE_SSH_PIDS=()
    local NODE_SSH_HOSTS=()
    local HOSTT=""
    while read HOSTT
        do
            ((NODE_COUNT++))
            NODE_DIR="${NODES_DIR}/node${NODE_COUNT}_${HOSTT}"
            if [[ "$3" == "node" ]]
                then
                    local SOURCE_FILE="${NODE_DIR}/node.info"
                else
                    local SOURCE_FILE="$2"
            fi
            eval "$1 ${HOST_USER}@${HOSTT}:$SOURCE_FILE ${NODE_DIR}/${3}_${HOSTT}.info &"
            NODE_SSH_PIDS+=("$!")
            NODE_SSH_HOSTS+=("$HOSTT")
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)
    local k=0
    for((k=0;k<NODE_COUNT;k++))
        do
            if wait ${NODE_SSH_PIDS[${k}]} &> /dev/null
                then
                    echo "$3 data transfer from from ${NODE_SSH_HOSTS[${k}]} complete"
                else
                    echo "$3 data transfer from ${NODE_SSH_HOSTS[${k}]} failed" >&2
                    echo "Please verify ssh credentials and network connectivity to node ${NODE_SSH_HOSTS[${k}]}. Also ensure local host has enough disk space on /tmp with write access." >&2
                    exit 5
            fi
        done
}


# Node metrics collector
node_metrics_collector() {
    INFO_PATH="$1"
    echo "Instacollector_Redis cluster Node metrics" > $INFO_PATH 2>&1
    # Metrics logger
    metric() {
        printf '=%.0s' {1..100} >> $INFO_PATH 2>&1
        echo >> $INFO_PATH 2>&1
        echo "$1" >> $INFO_PATH 2>&1
        echo >> $INFO_PATH 2>&1
        eval "$2" >> $INFO_PATH 2>&1
        echo >> $INFO_PATH 2>&1
        printf '=%.0s' {1..100} >> $INFO_PATH 2>&1
        echo -e "\n\n" >> $INFO_PATH 2>&1
    }

    # Getting redis process list
    REDIS_PROCESS_LIST=$($2 ps -ef | grep redis-server | grep -v grep | awk '{print $2}')

    # Collecting Redis Node info metrics
    metric "Redis cluster node:" "$2 hostname"
    metric "Node current date:" "$2 date"
    metric "Node details:" "$2 hostnamectl"
    metric "Node logger user details:" "$2 id"
    metric "Node time details:" "$2 timedatectl"
    metric "Node uptime and load avg:" "$2 uptime"
    metric "Node Linux Standard Base and Distribution:" "$2 lsb_release -a"
    metric "Node OS release details:" "$2 cat /etc/*release"
    metric "Node System information:" "$2 uname -a"
    metric "Node CPU details:" "$2 lscpu"
    metric "Node CPU core usage:" "$2 top -1 -bcn 1 -o %CPU -w 300"
    metric "Node Process list in decending order of CPU consumption:" "$2 ps -eo rss,vsz,drs,%mem,%cpu,pid,euser,args:100,lstart,etime --sort -%cpu"
    metric "Node Memory Summary:" "$2 free -hw"
    metric "Node Memory Details:" "$2 cat /proc/meminfo"
    metric "Node Process list in decending order of MEMORY consumption:" "$2 ps -eo rss,vsz,drs,%mem,%cpu,pid,euser,args:100,lstart,etime --sort -%mem"
    metric "Node Swap file info:" "$2 cat /proc/swaps"
    metric "Node Transparent hugepage status:" "cat /sys/kernel/mm/transparent_hugepage/enabled"
    metric "Node Disk Space:" "$2 df -h"
    metric "Redis directory:" "$2 ls -ltrha ${REDIS_DIR}"
    metric "Redis-server current open files count:" "$2 ls /proc/$(ps -ef | grep redis-server | grep -v grep | awk '{print $2}' | paste -s -d, -)/fd | wc -l"
    metric "Redis-server process limits:" "$2 cat /proc/$(ps -ef | grep redis-server | grep -v grep | awk '{print $2}')/limits"
    metric "Node Network interfaces:" "$2 ip a"
    metric "Node Socket Stat Summary:" "$2 ss -s"
    metric "Node Open ports:" "$2 ss -tulpne" 
    metric "Node system log size:" "$2 ls -ltrha /var/log"
    metric "Node system log - last 200 entries:" "$2 journalctl -a --no-pager -n 200"
    metric "Node Kernel Parameters:" "$2 sysctl -a" 
    metric "Node Block device details:" "$2 lsblk -a"  
    metric "Node Total number of Open Files:" "$2 lsof | wc -l"
    metric "Node Hardware Information from DMI:" "$2 dmidecode"
    metric "Node Hardware List:" "$2 lshw"
    ls "$INFO_PATH" &> /dev/null
}
    

# Cluster metrics collector
cluster_metrics_collector() {
    create_dir "nodes"
    NODES_DIR="${TEMP_DIR}/nodes"
    echo
    read -p "Please enter the ssh username for connecting to the Redis cluster nodes: " HOST_USER
    read -p "Please enter the full path to the user's private ssh key for connecting to Redis cluster nodes: " PRIVATE_KEY
    check_ssh_key "$PRIVATE_KEY"

    # Password-less sudo access check
    print_selection "Does the user: ${HOST_USER} have password-less sudo access on the redis nodes?"
    select SUDO_ACCESS in "Yes" "No" "exit"
        do
            case $SUDO_ACCESS in
                Yes) 
                    print_selection "You have confirmed Password-less sudo access for ${HOST_USER}"
                    SUDO="sudo"
                    break;;
                No)
                    print_selection "Password-less sudo missing. Instacollector_Redis wont be able to collect some data. Proceeding without sudo..."
                    SUDO=""
                    break;;
                exit)
                    exit_user;;
                *) 
                    invalid_choice;;
            esac
        done

    # Validating ssh credentials and creating required tmp dirs on nodes
    create_remote_dir "$NODES_DIR"

    # Get redis file locations on the cluster nodes
    echo
    read -p "Please enter the full path to the Redis working directory on the cluster nodes: " REDIS_DIR
    check_redispath "$REDIS_DIR"
    echo
    read -p "Please enter the full path to the Redis conf file on the cluster nodes: " REDIS_CONF
    check_redispath "$REDIS_CONF"
    echo
    read -p "Please enter the full path to the Redis log file on the cluster nodes: " REDIS_LOG
    check_redispath "$REDIS_LOG"


    # Running node metrics collector on all the nodes
    echo
    echo "Starting node metrics collector on Redis nodes..."
    echo "This may take sometime depending on the number of redis nodes in your cluster. PLEASE WAIT..."
    echo
    COUNT=0
    SSH_PIDS=()
    SSH_HOSTS=()
    while read HOST
        do
            ((COUNT++))
            NODE_DIR="${NODES_DIR}/node${COUNT}_${HOST}"
            mkdir -p $NODE_DIR
            NODE_FILE="${NODE_DIR}/node.info"
            ssh -o "StrictHostKeyChecking no" -q -n -i $PRIVATE_KEY ${HOST_USER}@${HOST} "$(typeset -f node_metrics_collector); export REDIS_DIR=$REDIS_DIR ; node_metrics_collector $NODE_FILE $SUDO" &
            SSH_PIDS+=("$!")
            SSH_HOSTS+=("$HOST")
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)
    
    for((i=0;i<COUNT;i++))
        do
            if wait ${SSH_PIDS[${i}]} &> /dev/null
                then
                    echo "Redis Node metrics collection complete on ${SSH_HOSTS[${i}]}"
                else
                    echo "Redis Node metrics collection failed on ${SSH_HOSTS[${i}]}" >&2
                    echo "Please verify ssh connectivity/credentials and ensure that node ${SSH_HOSTS[${i}]} has enough disk space on /tmp with write access." >&2
                    exit 51
            fi
        done
    
    print_selection "Redis Node metrics collection attempt complete on all the nodes."

    if [[ $SUDO == "sudo" ]]
        then
            FT_MODE="SFTP"
        else
            # File transfer option
            print_selection "Please choose if you want to use SCP(RECOMMENDED) or SFTP(COMPATIBILITY) for file transfer."
            select FT_MODE in "SCP" "SFTP" "exit"
                do
                    case $FT_MODE in
                        "SCP")
                            print_selection "You have selected SCP for file transfer."
                            break;;
                        "SFTP")
                            print_selection "You have selected SFTP for file transfer."
                            break;;
                        "exit")
                            exit_user;;
                        *) 
                            echo "Invalid input. Please enter 1 for SCP file transfer or 2 for SFTP file transfer or 3 to EXIT." >&2
                            ;;
                    esac
                done
    fi

    # Configuring file transfer based on selection   
    if [[ "$FT_MODE" == "SCP" ]]
        then
            FT="scp -o 'StrictHostKeyChecking=no' -o 'BatchMode=yes' -o 'PasswordAuthentication=no' -o 'PubkeyAuthentication=yes' -q -i $PRIVATE_KEY"
        else
            FT="sftp -o 'StrictHostKeyChecking=no' -o 'BatchMode=yes' -o 'PasswordAuthentication=no' -o 'PubkeyAuthentication=yes' -q -i $PRIVATE_KEY"
            if [[ $SUDO == "sudo" ]]
                then
                    FT+=" -s 'sudo /usr/lib/openssh/sftp-server'"
            fi
    fi

    echo "Attempting to transfer captured node metrics and redis conf/log data to local machine."
    echo "This may take sometime depending on the number of redis nodes in your cluster, network bandwidth and size of the redis log. PLEASE WAIT..."
    echo
    # Collecting metrics data from all the nodes
    TRANSFER_PIDS=()
    TRANSFER_TYPE=()
    node_transfer "$FT" "$NODES_DIR" "node" &
    TRANSFER_PIDS+=("$!")
    TRANSFER_TYPE+=("node")
    node_transfer "$FT" "$REDIS_CONF" "redisconf" &
    TRANSFER_PIDS+=("$!")
    TRANSFER_TYPE+=("redisconf")
    node_transfer "$FT" "$REDIS_LOG" "redislog" &
    TRANSFER_PIDS+=("$!")
    TRANSFER_TYPE+=("redislog")

    
    for ((j=0;j<3;j++))
    do
        if wait ${TRANSFER_PIDS[${j}]} &> /dev/null
            then
                print_selection "${TRANSFER_TYPE[${j}]} data transfer process complete."
            else
                echo "${TRANSFER_TYPE[${j}]} data transfer process failed." >&2
                echo "Please verify ssh connectivity/credentials for file access and ensure local host has enough disk space on /tmp with write access." >&2
                exit 5
        fi
    done
}


# Redis metrics collector
redis_metrics_collector() {
    # Verify if local redis client is available
    echo
    echo "Checking if local redis-cli is present..."
    if which redis-cli &> /dev/null
        then
            echo "redis-cli client is locally available. Proceeding to setup local temp directory."
            echo
        else
            echo "Unable to find redis-cli client."
            echo "Please ensure that redis-cli is available locally and is accessible via PATH environment variable." >&2
            exit 6
    fi
    create_dir "rediscluster"
    REDIS_LOCAL_DIR=${TEMP_DIR}/rediscluster
    REDIS_COMMAND="timeout 16s redis-cli --no-auth-warning"

    # Redis metrics logger

    redis_metrics() {
        redis_metric() {
        printf '=%.0s' {1..100}
        echo
        echo $1
        echo
        eval $2
        echo
        printf '=%.0s' {1..100}
        echo -e "\n\n"
    }
    echo "Instacollector_Redis cluster metrics" > $2 2>&1
    echo "Collected on: $(date)" >> $2 2>&1
    echo "REDIS CLUSTER NODE:PORT - ${HOST}:${REDIS_PORT}" >> $2 2>&1
    echo >> $2 2>&1
    redis_metric "REDIS CLUSTER NODES:" "${1} cluster nodes" >> $2 2>&1
    redis_metric "REDIS CLUSTER INFO:" "${1} cluster info" >> $2 2>&1
    redis_metric "REDIS-SERVER INFO:" "${1} info" >> $2 2>&1
    redis_metric "REDIS-SERVER CLIENT LIST:" "${1} client list" >> $2 2>&1
    redis_metric "REDIS-SERVER LATENCY:" "${1} --latency --raw" >> $2 2>&1
    redis_metric "REDIS-SERVER SLOWLOG:" "${1} slowlog get 128" >> $2 2>&1
    redis_metric "REDIS CLUSTER SHARDS:" "${1} cluster shards" >> $2 2>&1
    redis_metric "REDIS CLUSTER SLOTS:" "${1} cluster slots" >> $2 2>&1
}
        
    # Get Redis port
    while true
    do
        echo
        read -p "Please enter the Redis client connection port(generally 6379): " REDIS_PORT
        if [[ "${REDIS_PORT}" =~ ^[0-9]+$ ]]
            then
                if (( $REDIS_PORT >= 1024 && $REDIS_PORT <= 65535))
                    then
                        print_selection "Redis port has been set to ${REDIS_PORT}"
                        break
                    else
                        printf '\n%s\n\n' "Port $REDIS_PORT out of range. Please enter a valid port number" >&2 
                fi
            else
                printf '\n%s\n\n' "Invalid port ${REDIS_PORT}. Please enter a valid port number" >&2
        fi
    done

    # TLS check
    print_selection "Is TLS/SSL enabled on the Redis cluster(clients require certificate/key to allow a connection)?"
    select TLS in "Yes" "No" "exit"
        do
            case $TLS in
                Yes) 
                    print_selection "You have confirmed TLS connection for Redis cluster"

                    print_selection "Is the TLS one-way(you only need a CA certificate) or two-way/mutual(you need redis client's certificate, private key and the CA certificate)?"
                    select TLS_TYPE in "TLS one-way" "TLS two-way/mutual" "exit"
                        do
                            case $TLS_TYPE in
                                "TLS one-way")
                                    print_selection "One-way TLS selected to establish trust for TLS encryption."
                                    read -p "Please enter the full path to the CA certificate file: " REDIS_CA
                                    check_tls_cert "$REDIS_CA"
                                    REDIS_COMMAND+=" --tls --cacert ${REDIS_CA}"
                                    break;;
                                "TLS two-way/mutual")
                                    print_selection "Two-way/Mutual TLS selected to establish trust for TLS encryption."
                                    read -p "Please enter the full path to the CA certificate file: " REDIS_CA
                                    check_tls_cert "$REDIS_CA"
                                    REDIS_COMMAND+=" --tls --cacert ${REDIS_CA}"
                                    read -p "Please enter the full path to the Redis client certificate file: " REDIS_CERT
                                    check_tls_cert "$REDIS_CERT" 
                                    REDIS_COMMAND+=" --cert ${REDIS_CERT}"
                                    read -p "Please enter the full path to the Redis client key file: " REDIS_KEY
                                    check_ssh_key "$REDIS_KEY"     
                                    REDIS_COMMAND+=" --key ${REDIS_KEY}"
                                    break;;
                                "exit")
                                    exit_user;;
                                *)
                                    echo >&2
                                    echo "Invalid entry. Please enter 1 for one-way TLS or 2 for two-way/mutual TLS or 3 to EXIT" >&2
                                    echo >&2 ;;
                            esac    
                        done
                    break;;
                No)
                    print_selection "You have confirmed native(non-TLS) connection for Redis"
                    break;;
                exit)
                    exit_user;;
                *) 
                    invalid_choice;;
            esac
        done

    # Authentication check
    print_selection "Does redis client connection require password authentication?"
    select PASS in "Yes" "No" "exit"
        do        
            case $PASS in
                Yes) 
                    print_selection "You have confirmed that Redis has password authentication."
                    echo "Do you have a Redis username and password pair? Select 'No' if you want to use the default Redis password."
                    select USER_PRESENT in "Yes" "No" "exit"
                        do
                            case $USER_PRESENT in
                                Yes)
                                    print_selection "You have confirmed to use a Redis username and password pair."
                                    read -p "Please enter the Redis username: " REDIS_USER
                                    REDIS_COMMAND+=" --user ${REDIS_USER}"
                                    REDIS_PASS=$(get_pass "Please enter the password for ${REDIS_USER}: ")
                                    REDIS_COMMAND+=" --pass ${REDIS_PASS}"
                                    break;;
                                No)
                                    print_selection "You have confirmed to use the default password for Redis."
                                    REDIS_PASS=$(get_pass "Please enter the default password for Redis: ")
                                    REDIS_COMMAND+=" -a ${REDIS_PASS}"
                                    break;;
                                exit)
                                    exit_user;;

                                *)    
                                    invalid_choice;;
                            esac
                        done
                    break;;
                No)
                    print_selection "You have confirmed that Redis has no password."
                    break;;
                exit)
                    exit_user;;
                *) 
                    invalid_choice;;
            esac
        done
    # Redis connectivity check
    print_selection "Checking connectivity to redis cluster from local host..."
    while read HOST
        do
            REDIS_HOST_COMMAND="$REDIS_COMMAND -h $HOST -p $REDIS_PORT"
            REDIS_REPLY=$($REDIS_HOST_COMMAND ping)
            if [[ "$REDIS_REPLY" == "PONG" ]]
                then
                    echo "Redis connectivity verified for ${HOST}:${REDIS_PORT}"    
                else
                    echo "Unable to connect to redis cluster host $HOST on port $REDIS_PORT using the provided credentials." >&2
                    echo "Please check the connectivity/credentials to the redis cluster node and try again." >&2
                    exit 7
            fi
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)
 
    # Collect Redis metrics
    echo
    echo "Starting metrics collection from the Redis cluster..."
    echo "This may take awhile depending on the number of redis nodes in your cluster..."
    echo
    REDIS_COUNT=0
    REDIS_PIDS=()
    REDIS_HOSTS=()
    while read HOST
        do
            ((REDIS_COUNT++))
            REDIS_LOCAL_FILE="$REDIS_LOCAL_DIR/rcnode_${HOST}.info"
            REDIS_HOST_COMMAND="$REDIS_COMMAND -h $HOST -p $REDIS_PORT"
            if [[ REDIS_COUNT -eq 1 ]]
                then
                    echo "Performing Redis cluster check. PLEASE WAIT..."
                    echo
                    CLUSTER_CHECK_FILE=${REDIS_LOCAL_DIR}/cluster_check.info
                    echo -e "REDIS CLUSTER CHECK:\n" >> ${CLUSTER_CHECK_FILE} 2>&1
                    eval "$REDIS_HOST_COMMAND --cluster check ${HOST}:${REDIS_PORT} | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g'" >> ${CLUSTER_CHECK_FILE} 2>&1
            fi
            echo "Collecting Redis cluster metrics from ${HOST}:${REDIS_PORT}..."
            redis_metrics "$REDIS_HOST_COMMAND" "$REDIS_LOCAL_FILE" &  
            REDIS_PIDS+=("$!")
            REDIS_HOSTS+=("$HOST")
        done <<< $(egrep '[0-9]|[a-zA-Z]' redis_cluster_nodes.list)
    
    for((i=0;i<REDIS_COUNT;i++))
        do
            if wait ${REDIS_PIDS[${i}]} &> /dev/null
                then
                    echo "Redis cluster metrics collection from ${REDIS_HOSTS[${i}]}:${REDIS_PORT} complete"
                else
                    echo "Redis cluster metrics collection failed for ${REDIS_HOSTS[${i}]}:${REDIS_PORT}" >&2
                    echo "Please check redis connectivity/credentials and ensure that local host has enough disk space on /tmp with write access." >&2
                    exit 8
            fi
        done
}


# Main function
main() {

cat << EOF
# ---------------------------------------------------------------------------------#----------------------------------- #
# Instacollector_Redis - A Redis node metrics and log collector for Redis clusters #                                    #
# ---------------------------------------------------------------------------------#                                    #
#                                                                                                                       #
# Instacollector_Redis is an interactive command-line metrics collection tool for open source Redis clusters. It is     #
# designed to gather diagnostic information to help review a cluster's state. As the script is interactive, input       #
# parameters are not required. Options have been provided to collect metrics from the Redis nodes(via ssh) or cluster   #
# stats(via redis-cli) or both(recommended).                                                                            #
#                                                                                                                       #
# For collecting node level metrics and conf/log files, the localhost should have ssh-private key access to all the     #
# nodes in the Redis cluster. It is recommended for the ssh user to have password-less sudo access on the Redis nodes   #
# to be able to collect all the required metrics. If sudo access is not available, you can still attempt collection as  #
# the ssh user but we may get truncated data on some metrics. Please ensure that the ssh user has access to read the    #
# Redis working directory and files in-order to be able to collect the required data. The /tmp directory will be used   #
# on the Redis nodes for metrics collection. Please ensure that the /tmp directory is writable and has enough disk      #  
# space on all the Redis nodes(~150KB each).                                                                            #
#                                                                                                                       #
# For gathering cluster stats, the localhost should have redis-cli installed and setup on the system-wide PATH. If you  #
# don't already have redis-cli, please ensure that you install the latest version. Only redis-cli versions 6 and above  #
# have TLS support. Instructions for installation: https://redis.io/docs/getting-started/installation/                  #
# The redis-cli client will be used to directly gather live metrics from the Redis cluster. Hence, please ensure that   #
# the localhost has access to connect to the Redis cluster's client port(default: 6379). If TLS/SSL is enabled on Redis,# 
# please ensure that the required Redis client certificate and key along with the CA certificate are locally available. #
#                                                                                                                       #
# Instacollector_Redis gets the the Redis cluster connection information from the redis_cluster_nodes.list file in      #
# the same directory. Please enter the IP/DNS of all the nodes in your Redis cluster in redis_cluster_nodes.list        #
# before attempting a run. The file should only contain a list of either the IP or DNS of each node in the Redis        #
# cluster and each IP/DNS should be on a separate line. Please refer to the file format of redis_cluster_nodes.list     #
# which is available in the same directory of the git repo as an example. Please remove the existing IPs on it and add  #
# the ones for you Redis cluster nodes.                                                                                 #
#                                                                                                                       #
# Once all the required information is provided to Instacollector_Redis, it will attempt to connect and acquire the     #
# required metrics from the Redis cluster.                                                                              #
#                                                                                                                       #
# The Redis cluster's node metrics, conf/logs and stats are packaged into a tarball for easy consumption in the /tmp    #
# directory of the localhost. Please ensure that /tmp directory is writable and has enough disk-space on the localhost. #
# Ex: For a fresh 6 node cluster the uncompressed space required would be around 1 MB on the localhost.                 # 
#                                                                                                                       #
# --------------------------------------------------------------------------------------------------------------------- #
EOF
echo

# redis_cluster_nodes.list check
if [[ -s redis_cluster_nodes.list ]]
    then
        print_selection "Redis cluster nodes as per the redis_cluster_nodes.list file:"
        cat redis_cluster_nodes.list
        echo
        print_selection "Please confirm if the above IP/DNS address list is correct for your Redis cluster nodes."
        select REDIS_CLUSTER_NODES in "Yes" "No"
            do
                case $REDIS_CLUSTER_NODES in
                    Yes)
                        print_selection "Redis cluster nodes list user-verified."
                        break;;
                    No)
                        print_selection "Please update the redis_cluster_nodes.list file and try again." >&2
                        exit 1;;
                    *) 
                        echo "Invalid input. Please enter 1 for YES or 2 for NO." >&2
                        ;;
                esac
            done
    else
        echo "Unable to find a valid redis_cluster_nodes.list file." >&2
        echo "Please check and ensure that redis_cluster_nodes.list file is present and updated in the script's directory." >&2
        exit 1
fi
echo
echo "Please select the metrics you would like to collect from the Redis Cluster." 
echo "Metrics from REDIS NODES requires shh connection to the Redis cluster nodes via a PRIVATE key file."
echo "Metrics from REDIS CLUSTER requires access to redis-cli client via the PATH environment variable and Redis username/password."
echo "Option 1 is RECOMMENDED."
echo
select METRICS in "REDIS NODES AND REDIS CLUSTER" "REDIS NODES ONLY" "REDIS CLUSTER ONLY" "EXIT"
    do
        case $METRICS in
            "REDIS NODES AND REDIS CLUSTER")
                print_selection "You have selected to collect metrics from both the Redis nodes and the Redis cluster."
                print_selection "Initializing metrics collection for REDIS NODES..."
                cluster_metrics_collector
                print_selection "Initializing metrics collection for REDIS CLUSTER..."
                redis_metrics_collector
                break;;
            "REDIS NODES ONLY")
                print_selection "You have selected to collect metrics only from the Redis nodes."
                print_selection "Initializing metrics collection only for REDIS NODES..."
                cluster_metrics_collector
                break;;
            "REDIS CLUSTER ONLY")
                print_selection "You have selected to collect metrics only from the Redis cluster."
                print_selection "Initializing metrics collection only for REDIS CLUSTER..."
                redis_metrics_collector
                break;;
            "EXIT")
                print_selection "Exiting Instacollector_Redis as per user request"
                exit 0;;     
            *)
                echo "Invalid choice. Please enter 1, 2, 3 or 4 as per the options listed above." >&2
                ;;
        esac
    done

# Create final InstaRedis_collector metrics package
print_selection "Creating final InstaRedis_collector tarball ${TEMP_DIR}.tar.gz ..."
if tar -czf ${TEMP_DIR}.tar.gz ${TEMP_DIR} &> /dev/null
    then
        print_selection "InstaRedis_collector tarball created and available here: ${TEMP_DIR}.tar.gz"
    else
        echo
        echo "Unable to create the final metrics tarball on local host." >&2 
        echo "Please check permissions and available disk-space on /tmp and try again." >&2
        exit 8
fi
}

# Run main function
if [[ $# -eq 0 ]]
    then
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
            then
                main
        fi
    else
        echo -e "\nInput parameters are not expected.\nTry:\n $0 \n" >&2
fi
