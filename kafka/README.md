
This tool is used to collect information from a Kafka cluster to add in problem diagnosis or review.

Note: 
* This won't work on versions before kafka 2
* User is requested to change the path values in `node_collector.sh` before running any of the scripts, as by default the script uses `Kafka configuration file locations`, `data directory location`, and other setting locations as per **Apache Kafka** default setup.
* The term "VM" in environment of script `cluster_collector.sh` means if running in kernel.

# Design info:
There are two scripts used in instacollector tool for kafka.

1. `node_collector.sh`: supposed to be executed on each Kafka node. It executes Linux and Kafka commands and copies configuration and log files required for cluster health checks. The user needs to modify the `KAFKA_HOME` path inside the script as per their configurations, the default value used is:
```
KAFKA_HOME=/opt/kafka
```
2. `cluster_collector.sh`: to be executed on a machine connected to Kafka cluster e.g. user laptop with a running docker or a running VM. It executes node_collector.sh on each Kafka node using ssh. The cluster_collector.sh requires 4 user inputs :
```
   * Enter your kafka environment (vm/docker) :
     * [If VM]
       * Enter username for login on Kafka cluster nodes (Press Enter for default admin) :
       * Enter Identity file path: (the ssh key file in your local machine which is used to connect to the VMs)
     * [If docker]
       * Enter docker home directory:
   * Enter path of the command config file: (kafka command-config file location on the kafka brokers)
   * Enter file containing ip addresses/host/container names of Kafka cluster nodes: (the hosts file in your local machine)
```
*******************
# Execution settings:
The `cluster_collector.sh` has setting of connecting to cluster nodes using the provided ssh key file or an id file.

If the ssh key has passphrase enabled then please use `ssh-agent` & `ssh-add` commands to add the passphrase before running `cluster_collector.sh` script.

If there is another method required for `ssh`, user is requested to change the script as applicable.

Alternatively, the `node_collector.sh` can also be executed on individual nodes if `cluster_collector.sh` is not useful in any case.


Below are the Kafka & Zookeeper related files which will be copied from different nodes:
```
Kafka Broker Files                |  Zookeeper Files
**********************************|***********************
server.properties                 |  zookeeper.properties
server.log                        |  zoo.cfg
kafkaServer.out                   |  log4j.properties
kafka-authorizer.log              |  zoo.log
controller.log                    |  zookeeper_jaas.conf
state-change.log                  |  zookeeper.out
kafka_server_jaas.conf            |       
kafka-topics/.sh                  |
kafka-topics/.sh                  |
kafka-broker-api-versions/.sh     |
kafka-consumer-groups/.sh         |
server.properties
```

**Note:** The scripts should be executed on bash shell.

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project
