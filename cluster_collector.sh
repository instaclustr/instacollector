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
while getopts "u:p:" opt
do
case "$opt" in
    u ) parameter_username="$OPTARG" ;;
    p ) parameter_password="$OPTARG" ;;
    ? ) help_function ;; # Print help_function in case parameter is non-existent
esac
done

#GLOBAL VARIABLES
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_DIR=/tmp/InstaCollection_$(date +%Y%m%d%H%M)

#Collect user info.
read -p "Enter username for login on Cassandra cluster nodes (Press Enter for default admin) :" user
[ -z "${user}" ] && user='admin'

read -p "Enter Identity file path:" id_file
if [[ ! -f ${id_file} || ! -s ${id_file} ]]; then
    echo "$id_file File not found!" 
    exit 1
fi

read -p "Enter file containing ip addresses/host names of Cassandra cluster nodes:" peers_file
if [[ ! -f ${peers_file} || ! -s ${peers_file} ]]; then
    echo "$peers_file File not found!"
    exit 1
fi

#Execute the node_collector on each node
if ! [[ -z "${parameter_username}" && -z "${parameter_password}" ]];
then
    while read peer 
    do 
        if [ -z "$(ssh-keygen -F $peer)" ]; then
            ssh-keyscan -H $peer >> ~/.ssh/known_hosts
        fi
        
        ssh -i $id_file $user@$peer "bash -s" < node_collector.sh -u $parameter_username -p $parameter_password &
    done < "$peers_file"
else
    while read peer 
    do 
        if [ -z "$(ssh-keygen -F $peer)" ]; then
            ssh-keyscan -H $peer >> ~/.ssh/known_hosts
        fi
        
        ssh -i $id_file $user@$peer "bash -s" < node_collector.sh &
    done < "$peers_file"
fi


#waiting for all node_collectors to complete
wait

mkdir $INFO_DIR

#copy the data from each node
while read peer 
do 
    mkdir $INFO_DIR/$peer
    scp -i $id_file $user@$peer:/tmp/InstaCollection.tar.gz $INFO_DIR/$peer/InstaCollection_$peer.tar.gz &

done < "$peers_file"

#waiting for all scp to complete
wait

#compress the info directory 
result_file=/tmp/InstaCollection_$(date +%Y%m%d%H%M).tar.gz
tar -zcf $result_file -C $INFO_DIR .
rm -r $INFO_DIR

echo "Process complete. File generated : " $result_file