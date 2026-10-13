#!/bin/bash

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
while getopts "u:p:i:t" opt
do
case "$opt" in
    u ) parameter_username="$OPTARG" ;;
    p ) parameter_password="$OPTARG" ;;
    t ) useTLS="$OPTARG" ;;
    ? ) help_function ;; # Print help_function in case parameter is non-existent
esac
done

#GLOBAL VARIABLES
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_DIR=/tmp/InstaCollection_$(date +%Y%m%d%H%M)

# -- Environment info (SSH/Docker)
read -p "Enter your ClickHouse environment [SSH|Docker]: " kenv

kenv=$(echo "$kenv" | tr '[:upper:]' '[:lower:]')

# -- SSH info
if [[ "${kenv}" == "ssh" ]]; then
  # -- Collect user info
  read -p "Enter SSH username for login on ClickHouse cluster nodes [admin]: " ssh_user
  [ -z "${ssh_user}" ] && ssh_user='admin'

  read -p "Enter SSH Identity file path [none]: " id_file
  if [[ ! -z $id_file ]]; then
    if [[ ! -f ${id_file} || ! -s ${id_file} ]]; then
        echo "$id_file File not found!"
        exit 1
    fi
  fi

# -- Docker info
elif [[ "${kenv}" == "docker" ]]; then
  read -p  "Specify a writable directory inside the container to store the output [/tmp]: " docker_home
  if [ -z "$docker_home" ]; then
    docker_home="/tmp"
  fi

# -- Unknown selection
else
  echo "Invalid value for environment"
  exit 1
fi

#Collect user info.
read -p "Enter username for login on ClickHouse cluster nodes (Press Enter for default admin) :" clickhouse_user
[ -z "${clickhouse_user}" ] && clickhouse_user='admin'

read -p "Enter the password for $clickhouse_user on ClickHouse cluster nodes (Press Enter for default none) :" clickhouse_password
[ -z "${clickhouse_password}" ] && clickhouse_password=''

read -p "Use TLS for ClickHouse Connection  (Press Enter for default no) :" clickhouse_password
[ -z "${useTLS}" ] && useTLS=no

read -p "Enter file containing ip addresses/host names of ClickHouse cluster nodes:" peers_file
if [[ ! -f ${peers_file} || ! -s ${peers_file} ]]; then
    echo "$peers_file File not found!"
    exit 1
fi
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
####
     if ! [[ -z "${clickhouse_user}" && -z "${clickhouse_password}" ]];
     then
         while read peer
         do
             if [ -z "$(ssh-keygen -F $peer)" ]; then
                 ssh-keyscan -H $peer >> ~/.ssh/known_hosts
             fi

             ssh -i $id_file $user@$peer "bash -s" < node_collector.sh -u $clickhouse_username -p $clickhouse_password -t "$useTLS" &
         done < "$peers_file"
     else
         while read peer
         do
             if [ -z "$(ssh-keygen -F $peer)" ]; then
                 ssh-keyscan -H $peer >> ~/.ssh/known_hosts
             fi

             ssh -i $id_file $ssh_user@$peer "bash -s" < node_collector.sh -t "$useTLS" &
         done < "$peers_file"
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


     if ! [[ -z "${parameter_username}" && -z "${parameter_password}" ]]; then
       echo  docker exec $peer bash $docker_home/node_collector.sh -u $clickhouse_username -p $clickhouse_password -t "$useTLS" &
        docker exec $peer bash $docker_home/node_collector.sh -u $clickhouse_username -p $clickhouse_password  &
      else
      #  docker cp $config_file $peer:$docker_home/
      echo       docker exec $peer bash $docker_home/node_collector.sh -t "$useTLS" &
        docker exec $peer bash $docker_home/node_collector.sh -t "$useTLS"  &
      fi
  done < "$peers_file"

fi
#waiting for all node_collectors to complete
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
      echo   "docker cp $peer:$docker_home/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz &"
      docker cp $peer:$docker_home/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz &

  done < "$peers_file"

fi
#waiting for all scp to complete
wait

#compress the info directory 
result_file=/tmp/InstaCollection_$(date +%Y%m%d%H%M).tar.gz
tar -zcf $result_file -C $INFO_DIR .
rm -r $INFO_DIR

echo "Process complete. File generated : " $result_file