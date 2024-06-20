
This tool is used to collect information from a PostgresSQL cluster to add in problem diagnosis or review.

# Design info:
There is a script used in Instacollector tool. The `node_collector.sh` is supposed to be executed on each PostgresSQL node.

The `node_collector.sh` executes Linux and `psql` commands and copies configuration and log files required for cluster health check.


# Execution settings:
The `node_collector.sh` can also be executed on individual nodes.

The `node_collector.sh` supports arguments to provide version of PostgresSQL, database and username.

```
Usage: node_collector.sh -v version -d database -u username
    -v    version of PostgresSQL
    -d    database
    -u    username
```

The PostgresSQL configuration file locations, data directory location and other settings are used as per default setup.
**User is requested to change those in `node_collector.sh` if other values are required.**

**Note:** The scripts should be executed on bash shell.

Please see https://www.instaclustr.com/support/documentation/announcements/instaclustr-open-source-project-status/ for Instaclustr support status of this project
