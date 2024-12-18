#!/bin/bash

#==========================#
# --       Usage        -- #
#==========================#
# ./cluster_collector.sh
# bash cluster_collector.sh


#==========================#
# --      Purpose       -- #
#==========================#
# This tool will copy Kafka & Zookeeper/KRaft related configuration and log files for troubleshooting or cluster health review.


#==========================#
# --       Notes        -- #
#==========================#
# - Not all files listed below will exist for all clusters (e.g. KRaft and Zookeeper are mutually exclusive) but the 
#     script will still attempt to collect for both
# - Properties files with the word "password" in them will be redacted with "***"


#==========================#
# --   Expected Paths   -- #
#==========================#
# BROKER_CONFIG_PATH
#   └─server.properties
#
# BROKER_LOG_PATH
#   ├─server.log
#   ├─kafkaServer.out
#   ├─kafka-authorizer.log
#   ├─controller.log
#   └─state-change.log
#
# BROKER_JAAS_CONFIG
#   └─kafka_server_jaas.conf
#
# ZOOKEEPER_CONFIG
#   ├─zookeeper.properties
#   ├─zoo.cfg
#   └─log4j.properties
#
# ZOOKEEPER_LOG_PATH
#   ├─zoo.log
#   └─zookeeper.out
#
# ZOOKEEPER_JAAS_CONFIG
#   └─zookeeper_jaas.conf
#
# KRAFT_CONFIG_PATH
#   ├─server.properties
#   ├─controller.properties
#   └─broker.properties
#
# BROKER_BIN_PATH
#   ├─kafka-topics/.sh
#   ├─kafka-topics/.sh
#   ├─kafka-broker-api-versions/.sh
#   └─kafka-consumer-groups/.sh
#
# -- Other information gathered
# - Filesystem & data directory size 
# - IO Stats
# - File Descriptor limits
# - CPU & Memory usage 
# - Contents of the hosts file 
# - Output of various Kafka CLI tools  


#==========================#
# -- Collection Options -- #
#==========================#
# -- Global Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_DIR=/tmp/InstaCollection_$(date +%Y%m%d%H%M)

# -- Environment info (SSH/Docker)
read -p "Enter your Kafka environment [SSH|Docker]: " kenv

# -- SSH info
if [[ "${kenv}" == "SSH" ]]; then
  # -- Collect user info
  read -p "Enter SSH username for login on Kafka cluster nodes [admin]: " user
  [ -z "${user}" ] && user='admin'

  read -p "Enter Identity file path [none]: " id_file
  if [[ ! -z $id_file ]]; then
    if [[ ! -f ${id_file} || ! -s ${id_file} ]]; then
        echo "$id_file File not found!" 
        exit 1
    fi
  fi

# -- Docker info
elif [[ "${kenv}" == "Docker" ]]; then
  read -p  "Specify a writable directory inside the container to store the output [/tmp]: " docker_home
  if [ -z "$docker_home" ]; then
    docker_home="/tmp"
  fi

# -- Unknown selection
else
  echo "Invalid value for environment"
  exit 1
fi

# -- Command Config
read -p "Enter path of the command config file [none]: " config_file
if [ -z "${config_file}" ]; then
    unset config_file
  fi

read -p "Enter file containing ip addresses/host/container names of Kafka cluster nodes [./peers.txt]: " peers_file
if [[ -z $peers_file ]]; then
  peers_file="./peers.txt"
fi
if [[ ! -f ${peers_file} || ! -s ${peers_file} ]]; then
    echo "$peers_file File not found!"
    exit 1
fi

echo "Using environment $kenv"


#==========================#
# --    Collect Data    -- #
#==========================#
# -- Execute the node_collector with SSH
if [ "$kenv" == "SSH" ]; then
  while read peer 
  do 
    if [[ -z "$peer" ]]; then
      break
    fi

    if [[ -z $id_file ]]; then
      if [[ -z "$config_file" ]]; then 
        ssh $user@$peer "bash -s" < node_collector.sh -ip $peer
      else
        ssh $user@$peer "bash -s" < node_collector.sh -ip $peer -c $config_file
      fi
    else
      if [[ -z "$config_file" ]]; then 
        ssh -i $id_file $user@$peer "bash -s" < node_collector.sh -ip $peer &
      else
        ssh -i $id_file $user@$peer "bash -s" < node_collector.sh -ip $peer -c $config_file &
      fi
    fi
  done < "$peers_file"

# -- Execute the node_collector with Docker
else
  while read peer
  do
      if [[ -z "$peer" ]]; then
        break
      fi
      echo "Copying file node_collector.sh to container" 
      docker cp ./node_collector.sh $peer:$docker_home/
      
      if [[ -z "$config_file" ]]; then 
        docker exec $peer bash $docker_home/node_collector.sh -ip $peer &
      else
        docker cp $config_file $peer:$docker_home/
        docker exec $peer bash $docker_home/node_collector.sh -ip $peer -c $config_file &
      fi
  done < "$peers_file"
fi

# -- Wait for all node_collectors to complete
wait

mkdir $INFO_DIR

# -- Copy the data from each node with SSH
if [ "$kenv" == "SSH" ]; then
  while read peer 
  do 
      if [[ -z "$peer" ]]; then
        break
      fi
      mkdir $INFO_DIR/$peer

      if [[ -z $id_file ]]; then
        scp $user@$peer:/tmp/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz
      else
        scp -i $id_file $user@$peer:/tmp/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz &
      fi

  done < "$peers_file"

# -- Copy the data from each container with Docker
else
  while read peer
  do
      if [[ -z "$peer" ]]; then
        break
      fi
      mkdir $INFO_DIR/$peer
      docker cp $peer:$docker_home/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz & 

  done < "$peers_file"
  
fi

# -- Wait for all copy jobs to complete
wait

# -- Compress the info directory 
result_file=/tmp/InstaCollection_$(date +%Y%m%d%H%M).tar.gz
tar -zcf $result_file -C $INFO_DIR .
rm -r $INFO_DIR

echo "Process complete. File generated: " $result_file
