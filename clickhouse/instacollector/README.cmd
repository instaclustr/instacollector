

This tool is used to collect information from a ClickHouse cluster to add in problem diagnosis or review.

# Design info:
There are two scripts used in Instacollector tool. The `node_collector.sh` is supposed to be executed on each ClickHouse node.
The `cluster_collector.sh` can be executed on a machine connected to ClickHouse cluster e.g. user laptop or Jumpbox having connectivity with ClickHouse cluster.

The `node_collector.sh` executes Linux and nodetool commands and copies configuration and log files required for cluster health check.
The `cluster_collector.sh` executes `node_collector.sh` on each ClickHouse node using ssh.
It uses a file containing IP addresses or host names of ClickHouse cluster nodes to establish ssh connections.



# Execution settings:
The `cluster_collector.sh` has setting of connecting to cluster nodes using key file or id file.
If the ssh key has passphrase enabled then please use `ssh-agent` and `ssh-add` commands to add the passphrase before running `cluster_collector.sh`.
If there is another method required for `ssh`, user is requested to change the script as applicable.
Alternatively, the `node_collector.sh` can also be executed on individual nodes if `cluster_collector.sh `is not useful in any case.

The `cluster_collector.sh` supports arguments to provide username and password.  There is an optional argument to specify using TLS to make the connection.

```
Usage:: cluster_collector.sh 
```
It will prompt for the method of connecting to the  ClickHouse environment (ssh or Docker), a username and password for ClickHouse, and the file containing a list of IPs for the ClickHouse nodes.
If you are connecting via SSH, you will be prompted for a SSH username and the path to an identity file. 

```

Bellow is an example of a file containing `the list of IPs` to collect the data (one IP per line):

```
10.10.2.196
10.10.3.64
10.10.3.148
```

The ClickHouse configuration file locations, data directory location and other settings are used as per the  ClickHouse default setup.
**User is requested to change those in `node_collector.sh` if other values are required.**

**Note:** The scripts should be executed on bash shell.

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project

