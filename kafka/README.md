
This tool is used to collect information from a Kafka cluster to add in problem diagnosis or review.

# Design info:
There are two scripts used in instacollector tool. The `node_collector.sh` is supposed to be executed on each Kafka node.
The `cluster_collector.sh` can be executed on a machine connected to Kafka cluster e.g. user laptop or Jumpbox having connectivity
with Cassandra cluster.

The node_collector.sh executes Linux and Kafka commands and copies configuration and log files required for cluster health check.
The cluster_collector.sh executes node_collector.sh on each Kafka node using ssh. The cluster_collector.sh accepts 4 user inputs - 

Enter your kafka environment (vm/docker) :
Enter username for login on Kafka cluster nodes (Press Enter for default admin) :
Enter Identity file path: <the identify file in your local machine which is used to connect to the VMs>
Enter path of the command config file: <kafka command-config file location on the kafka brokers>
Enter file containing ip addresses/host/container names of Kafka cluster nodes: <the hosts file in your local machine>


# Execution settings:
The cluster_collector.sh has setting of connecting to cluster nodes using key file or id file.
If the ssh key has passphrase enabled then please use ssh-agent and ssh-add commands to add the passphrase before running cluster_collector.sh.
If there is another method required for `ssh`, user is requested to change the script as applicable.
Alternatively, the node_collector.sh can also be executed on individual nodes if cluster_collector.sh is not useful in any case.

The Kafka configuration file locations, data directory location and other settings are used as per Apache Kafka default setup.
User is requested to change those in node_collector.sh if other values are required. Below are the Kafka & Zookeeper related files 
which are copied from different nodes.

Kafka Broker Files
*******************
server.properties
server.log
kafkaServer.out
kafka-authorizer.log
controller.log
state-change.log
kafka_server_jaas.conf
kafka-topics/.sh
kafka-topics/.sh
kafka-broker-api-versions/.sh
kafka-consumer-groups/.sh 

Zookeeper Files
****************
zookeeper.properties
zoo.cfg
log4j.properties
zoo.log
zookeeper_jaas.conf
zookeeper.out


**Note:** The scripts should be executed on bash shell.

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project
