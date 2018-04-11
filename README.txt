
Design info:
There are two scripts used in instacollector tool. The 'nodeCollector.sh' is supposed to be executed on each Cassandra node. 
The 'clusterCollector.sh' can be executed on a machine connected to Cassandra cluster e.g. user laptop or Jumpbox having connectivity 
with Cassandra cluster. 

The nodeCollector.sh executes Linux and nodetool commands and copies configuration and log files required for cluster health check.
The clusterCollector.sh executes nodeCollector.sh on each Cassndra node using ssh. 
It uses a file containing IP addresses or host names of Cassandra cluster nodes to establish ssh connections.



Execution settings:
The clusterCollector.sh has setting of connecting to cluster nodes using key file or id file. 
If there is another method required for 'ssh', user is requested to change the script as applicable.
Alternatively, the nodeCollector.sh can also be executed on individual nodes if clusterCollector.sh 
is not useful in any case.

The Cassandra configuration file locations, data directory location and other settings are used as per Apache Cassandra default setup.
User is requested to change those in nodeCollector.sh if other values are required.  

Note: The scripts should be executed on bash shell.

