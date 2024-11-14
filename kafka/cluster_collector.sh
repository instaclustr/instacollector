#!/bin/bash

##********************************************************************************************************************
##********************************************************************************************************************
## The purpose of this tool is to extract kafka & zookeeper related configuration and log files for troubleshooting. 
## Following are the list of files that are extracted. Please note that not all files exists in an environment. 
## All properties with the word "password" in it are replaced with "***" 
#=============================================================#
# kafka files and the path variables where they are expected
# BROKER_CONFIG_PATH
#   server.properties
# BROKER_LOG_PATH
#   server.log
#   kafkaServer.out
#   kafka-authorizer.log
#   controller.log
#   state-change.log
# BROKER_JAAS_CONFIG
#   kafka_server_jaas.conf
# ZOOKEEPER_CONFIG
#   zookeeper.properties
#   zoo.cfg
#   log4j.properties
# ZOOKEEPER_LOG_PATH
#   zoo.log
# ZOOKEEPER_JAAS_CONFIG
#   zookeeper_jaas.conf
# ZOOKEEPER_LOG_PATH
#   zookeeper.out
# BROKER_BIN_PATH
#   kafka-topics/.sh
#   kafka-topics/.sh
#   kafka-broker-api-versions/.sh
#   kafka-consumer-groups/.sh 
#=============================================================#      
##
## In addition to the files above the script also extract the following OS related information - 
## 1. file system & directory size 
## 2. io stats
## 3. file descriptors
## 4. cpu & memory 
## 5. contents of the hosts file 
## 6. output of kafka-topics.sh topic describe 
## 
##********************************************************************************************************************
##********************************************************************************************************************
## Last Modification Date : 10/29/2021
## Description		 : Script functionality enhanced to add information related to iostat, df, file descriptor
##                          cpu & memory info 
##********************************************************************************************************************
##********************************************************************************************************************

clear

#GLOBAL VARIABLES
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_DIR=/tmp/InstaCollection_$(date +%Y%m%d%H%M)

#Collect environment info (VM/docker)
read -p "Enter your kafka environment (vm/docker) :" kenv

if [[ "${kenv}" == "vm" ]]; then
  #Collect user info.
  read -p "Enter username for login on Kafka cluster nodes (Press Enter for default admin) :" user
  [ -z "${user}" ] && user='admin'

  #user='rahulchakrabarty'

  read -p "Enter Identity file path:" id_file
  if [[ ! -f ${id_file} || ! -s ${id_file} ]]; then
      echo "$id_file File not found!" 
      exit 1
  fi

  #id_file='/Users/rahulchakrabarty-instaclustr/.ssh/rahulchakrabarty-instaclustr'
elif [[ "${kenv}" == "docker" ]]; then
  read -p "Enter docker home directory :" docker_home

  if [ -z "$docker_home" ]; then
    echo "Docker home directory cannot be empty"
    exit 1
  fi
else
  echo "Invalid value for environment"
  exit 1
fi

read -p "Enter path of the command config file:" config_file

read -p "Enter file containing ip addresses/host/container names of Kafka cluster nodes:" peers_file
if [[ ! -f ${peers_file} || ! -s ${peers_file} ]]; then
    echo "$peers_file File not found!"
    exit 1
fi

#peers_file='./hosts'

echo "environment $kenv"

#Execute the node_collector on each node or container
if [ "$kenv" == "vm" ]; then
  while read peer 
  do 
          if [[ -z "$peer" ]]; then
            break
          fi
          ssh -i $id_file $user@$peer "bash -s" < node_collector.sh $peer $config_file &
  done < "$peers_file"
else
  while read peer
  do
      if [[ -z "$peer" ]]; then
        break
      fi
      echo "Copying file node_collector.sh to container" 
      docker cp ./node_collector.sh $peer:$docker_home/
      docker exec $peer /bin/bash -c "sh $docker_home/node_collector.sh $peer $config_file" &
  done < "$peers_file"
fi

#waiting for all node_collectors to complete
wait

mkdir $INFO_DIR

#copy the data from each node/container

if [ "$kenv" == "vm" ]; then
  while read peer 
  do 
      if [[ -z "$peer" ]]; then
        break
      fi
      mkdir $INFO_DIR/$peer
      scp -i $id_file $user@$peer:/tmp/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz &

  done < "$peers_file"
else
  while read peer
  do
      if [[ -z "$peer" ]]; then
        break
      fi
      mkdir $INFO_DIR/$peer
      docker cp $peer:/tmp/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz & 

  done < "$peers_file"
  
fi

#waiting for all scp to complete
wait

#compress the info directory 
result_file=/tmp/InstaCollection_$(date +%Y%m%d%H%M).tar.gz
tar -zcf $result_file -C $INFO_DIR .
rm -r $INFO_DIR

echo "Process complete. File generated : " $result_file
