
This tool is used to collect information from a Cassandra cluster to add in problem diagnosis or review.

# Design info:
There are two scripts used in Instacollector tool. The `node_collector.sh` is supposed to be executed on each Cassandra node.
The `cluster_collector.sh` can be executed on a machine connected to Cassandra cluster e.g. user laptop or Jumpbox having connectivity with Cassandra cluster.

The `node_collector.sh` executes Linux and nodetool commands and copies configuration and log files required for cluster health check.
The `cluster_collector.sh` executes `node_collector.sh` on each Cassandra node using ssh.
It uses a file containing IP addresses or host names of Cassandra cluster nodes to establish ssh connections.



# Execution settings:
The `cluster_collector.sh` has setting of connecting to cluster nodes using key file or id file.
If the ssh key has passphrase enabled then please use `ssh-agent` and `ssh-add` commands to add the passphrase before running `cluster_collector.sh`.
If there is another method required for `ssh`, user is requested to change the script as applicable.
Alternatively, the `node_collector.sh` can also be executed on individual nodes if `cluster_collector.sh `is not useful in any case.

The `cluster_collector.sh` supports optional arguments to provide username and password, to work with JMX authentication and is going to ask for the username to log into the cluster node OS, local path of the identity file and a file with the list of node IPs:

```
Usage: cluster_collector.sh [-u username -p password]
    -u    JMX agent username. [optional]
    -p    Password. [optional]
```

The `node_collector.sh` supports optional arguments to provide username and password, to work with JMX authentication:

```
Usage: node_collector.sh [-u username -p password]
    -u    JMX agent username. [optional]
    -p    Password. [optional]
```

Bellow is an example of a file containing `the list of IPs` to collect the data (one IP per line):

```
10.10.2.196
10.10.3.64
10.10.3.148
```

The Cassandra configuration file locations, data directory location and other settings are used as per Apache Cassandra default setup.
**User is requested to change those in `node_collector.sh` if other values are required.**

**Note:** The scripts should be executed on bash shell.

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project
