# Instacollector for Kafka
This tool is used to collect information from a Kafka cluster to add in problem diagnosis and cluster health review.

## Design
There are two scripts used in Instacollector for Kafka:

1. `node_collector.sh`: Executes Linux and Kafka commands and copies configuration and log files required for cluster health checks on each node. The user may need to modify the `KAFKA_HOME` path inside the script as per their configuration, the default value used is: `KAFKA_HOME=/opt/kafka`

2. `cluster_collector.sh`: Executes `node_collector.sh` on each Kafka node from a central machine with access to each node. `cluster_collector.sh` uses the following information:
  - **Environment**: [SSH|Docker]
    - for `SSH` environments the script will scp the node_collector and execute it. The script will additionaly ask for:
      - SSH username
      - path to SSH identity file
    - for `Docker` environments the script will use `docker exec` to run the node_collector. The script will additionaly ask for:
      - Docker Home directory: a path inside the containter where we can store the script and generated files (defaults to `/tmp`)
  - **Command Config**
    - path to the command config file to use for Kafka CLI tools (optional)
  - **Peers File**
    - file with a list of IPs/hostnames/containers to connect to


## Execution
The `cluster_collector.sh` has setting of connecting to cluster nodes using the provided ssh key file or an id file.

If the ssh key has a passphrase enabled then please use `ssh-agent` & `ssh-add` commands to add the passphrase before running `cluster_collector.sh` script with `eval "$(ssh-agent -s)"`. By default, `ssh-agent` should automatically load the keys in `~/.ssh` when started, if needed you can manually add a key from elsewhere with: `ssh-add path/to/key`

If another method is required for connecting to the target nodes with `ssh`, changes to the script may be required, alternatively the `node_collector.sh` can also be executed on individual nodes manually.


## Collected Information

### Files
Kafka & Zookeeper related files which will be copied:

| Kafka Broker Files             |  Zookeeper Files      |
| ------------------------------ | --------------------- |
| server.properties              |  zookeeper.properties |
| server.log                     |  zoo.cfg              |
| kafkaServer.out                |  log4j.properties     |
| kafka-authorizer.log           |  zoo.log              |
| controller.log                 |  zookeeper_jaas.conf  |
| state-change.log               |  zookeeper.out        |
| kafka_server_jaas.conf         |                       |
| broker.properties              |                       |
| controller.properties          |                       |

### Kafka CLI Commands

- `kafka-topics.sh --version`
- `kafka-metadata-quorum.sh --describe`
- `kafka-topics.sh --describe`
- `kafka-broker-api-versions.sh`
- `kafka-consumer-groups.sh --describe --all-groups --verbose`


## Notes
- These scripts target Kafka 3 and newer
- The target paths in `node_collector.sh` may need to be updated depending on the install location of Kafka/Zookeeper
- Scripts are intended to be run with `bash`


## Support Status

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project
