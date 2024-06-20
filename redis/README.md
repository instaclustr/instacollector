# Instacollector_Redis - A Redis node metrics and log collector for Redis clusters

Instacollector_Redis is an interactive command-line metrics collection tool for open source Redis clusters. It is       
designed to gather diagnostic information to help review a cluster's state. As the script is interactive, input         
parameters are not required. Options have been provided to collect metrics from the Redis nodes(via ssh) or cluster     
stats(via redis-cli) or both(recommended).                                                                              
                                                                                                                        
For collecting node level metrics and conf/log files, the localhost should have ssh-private key access to all the       
nodes in the Redis cluster. It is recommended for the ssh user to have password-less sudo access on the Redis nodes     
to be able to collect all the required metrics. If sudo access is not available, you can still attempt collection as    
the ssh user but we may get truncated data on some metrics. Please ensure that the ssh user has access to read the      
Redis working directory and files in-order to be able to collect the required data. The /tmp directory will be used     
on the Redis nodes for metrics collection. Please ensure that the /tmp directory is writable and has enough disk        
space on all the Redis nodes(~150KB each).                                                                              
                                                                                                                        
For gathering cluster stats, the localhost should have redis-cli installed and setup on the system-wide PATH. If you    
don't already have redis-cli, please ensure that you install the latest version. Only redis-cli versions 6 and above    
have TLS support. Instructions for installation: https://redis.io/docs/getting-started/installation/                    
The redis-cli client will be used to directly gather live metrics from the Redis cluster. Hence, please ensure that     
the localhost has access to connect to the Redis cluster's client port(default: 6379). If TLS/SSL is enabled on Redis,  
please ensure that the required Redis client certificate and key along with the CA certificate are locally available.   
                                                                                                                        
Instacollector_Redis gets the the Redis cluster connection information from the redis_cluster_nodes.list file in        
the same directory. Please enter the IP/DNS of all the nodes in your Redis cluster in redis_cluster_nodes.list          
before attempting a run. The file should only contain a list of either the IP or DNS of each node in the Redis          
cluster and each IP/DNS should be on a separate line. Please refer to the file format of redis_cluster_nodes.list       
which is available in the same directory of the git repo as an example. Please remove the existing IPs on it and add    
the ones for you Redis cluster nodes.                                                                                   
                                                                                                                        
Once all the required information is provided to Instacollector_Redis, it will attempt to connect and acquire the       
required metrics from the Redis cluster.                                                                                
                                                                                                                        
The Redis cluster's node metrics, conf/logs and stats are packaged into a tarball for easy consumption in the /tmp      
directory of the localhost. Please ensure that /tmp directory is writable and has enough disk-space on the localhost.   
Ex: For a fresh 6 node cluster the uncompressed space required would be around 1 MB on the localhost.                  
                                                                                                                            
                                                                                                                        