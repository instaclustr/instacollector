
SET param_cluster='cluster_2R_2S'


# Number of replicas & shards *
# 3 replicas per shard
##  select * from clusterAllReplicas({cluster:String}, system.databases) format vertical ;
SELECT
 cluster,
 max(shard_num) as shards,
 max(replica_num) as replicas
 from clusterAllReplicas( {cluster:String}, system.clusters )
 group by cluster

SELECT  * from clusterAllReplicas ( {cluster:String} , system.clusters) \G




# ClickHouse Keeper on ClickHouse node *
# SELECT * FROM system.zookeeper WHERE path = '/clickhouse'


## Replicas *?

SELECT * from clusterAllReplicas ( {cluster:String} , system.replicas) \G


### PARTS

# Number of Active Parts *
SELECT
    {cluster:String} AS cluster_name,
    active,
    count() AS part_count,
    formatReadableSize(max(bytes_on_disk)) AS max_part_size
FROM clusterAllReplicas ( {cluster:String} ,system.parts)
GROUP BY active
ORDER BY part_count DESC



#Number of Active Mutations (maybe) *

SELECT   {cluster:String} AS cluster_name, count() FROM  clusterAllReplicas ( {cluster:String} ,system.mutations)
WHERE not is_done


# Number of Active Merges (maybe) *
SELECT 'ACTIVE MERGES' ;
SELECT
      {cluster:String} AS cluster_name,
    name,
    level,
    rows
FROM clusterAllReplicas( {cluster:String} , system.parts )
WHERE (database NOT LIKE 'system') AND (`table` LIKE '%') AND active
ORDER BY name ASC ;


# List Partitions * ?
SELECT hostname() as Host,
  substr(table, 1, 22) as table,
    partition ,
    name,
    part_type,
    rows, marks,
    bytes_on_disk,
    path
FROM clusterAllReplicas( {cluster:String} ,system.parts)
WHERE active=1

# Number of Partitions per user table * ?
SELECT
 substr(p.table, 1, 22) as table,
  uniq(p.partition) as partitions, count(*) as parts
FROM  clusterAllReplicas( {cluster:String} , system.parts ) p JOIN  clusterAllReplicas( {cluster:String} , system.tables ) t ON p.table=t.table
WHERE active=1 AND p.database NOT IN ( 'system', 'INFORMATION_SCHEMA')
GROUP BY table
ORDER BY table DESC

# Disk Information *

SELECT
    hostname() as Host,
    name,
    path,
    formatReadableSize(free_space) AS FreeSpace,
    formatReadableSize(total_space) AS TotalSpace,
    formatReadableSize(unreserved_space) AS UnreservedSpace,
    type,
    is_encrypted,
    is_read_only,
    is_write_once,
    is_broken,
    cache_path
FROM clusterAllReplicas( {cluster:String} , system.disks)
FORMAT VERTICAL


### Table Info

# List tables by DB

SELECT
   hostname() as Host,
   db.name ,
   tbl.name ,
   tbl.partition_key
   FROM system.databases db
   JOIN system.tables tbl on db.name = tbl.database
   WHERE db.name not in ('INFORMATION_SCHEMA', 'information_schema', 'system')

# LIST  select * from system.dictionaries ;
 SELECT  hostname() as host, * from clusterAllReplicas( {cluster:String} , system.dictionaries );

# table sizes *
SELECT
    hostname() as Host,
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) as bytes_on_disk,
    formatReadableSize(sum(data_compressed_bytes) AS size) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes) AS usize) AS uncompressed,
    round(usize / size, 2) AS compression_rate,
     formatReadableSize(sum(rows)) as rows,
    formatReadableSize(sum(marks)) as marks,
    count() AS part_count
FROM clusterAllReplicas( {cluster:String} , system.parts)
WHERE (active = 1) AND (database LIKE '%') AND (table LIKE '%')
GROUP BY
    database,
    table
ORDER BY size DESC;


# List skipping indices *
SELECT
  hostname() as Host,
  database,
  name as table_name,
  type as index_type,
  type_full ,
  expr as Index_Calculation,
  granularity as Granules,
  formatReadableSize(data_compressed_bytes) as Compressed_Size,
  formatReadableSize(data_uncompressed_bytes) as Uncompressed_Size,
  formatReadableSize(marks_bytes) as Marks_Size
from  system.data_skipping_indices


# column size
SELECT
    {cluster:String}  as Cluster_Name,
    database,
    table,
    column,
    formatReadableSize(sum(column_data_compressed_bytes) AS size) AS compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes) AS usize) AS uncompressed,
    round(usize / size, 2) AS compr_ratio,
    sum(rows) rows_cnt,
    round(usize / rows_cnt, 2) avg_row_size
FROM clusterAllReplicas( {cluster:String} ,system.parts_columns)
WHERE (active = 1) AND (database <> 'system') AND (table LIKE '%')
GROUP BY
    database,
    table,
    column
ORDER BY
    database ASC,
    `table` ASC,
    column ASC,
    size ASC


# what has changed *
    SELECT
    hostname() AS host,
    name as Parameter,
    value
FROM clusterAllReplicas( {cluster:String} ,system.settings)
WHERE changed
ORDER BY name


# Number of Active Parts
# max_part_size less than max_bytes_to_merge_at_min_space_in_pool
SELECT
        hostname() as Host ,
        formatReadableSize( cast(value as UInt64) ) as max_bytes_to_merge_at_min_space_in_pool
FROM clusterAllReplicas( {cluster:String}, system.merge_tree_settings )
WHERE name = 'max_bytes_to_merge_at_min_space_in_pool'

SELECT
  {cluster:String} as Cluster_Name,
    count() AS part_count,
   formatReadableSize( max(bytes_on_disk) AS max_part_size)
FROM clusterAllReplicas({cluster:String}, system.parts)
WHERE active = 1
ORDER BY part_count DESC


SELECT
  {cluster:String} as Cluster_Name,
  substr(p.table, 1, 22) as table,
  uniq(partition) as partition, count(*) as parts
FROM system.parts p JOIN system.tables t ON p.table=t.table
WHERE active=1 AND p.database <> 'system'
GROUP BY     table
ORDER BY partition DESC

 # active parts user tables
 SELECT
   {cluster:String} as Cluster_Name,
    concat(database, '.', table) as table,
    partition_id,
    count() as num_parts
FROM system.parts
WHERE active AND database <> 'system'
GROUP BY
    database,
    table,
    partition_id

 SELECT
     hostname() AS host,
    concat(database, '.', table) as table,
    partition_id,
    count() as num_parts
FROM system.parts
WHERE active AND database = 'system'
GROUP BY
    database,
    table,
    partition_id

# Number of Active Mutations

SELECT
   hostname() AS host,
   count() as number_mutations
   FROM system.mutations
   WHERE not is_done
   GROUP BY host;

# Number of Active Merges *

SELECT   hostname() AS host,
name,
level,
rows
FROM system.parts WHERE (database <>‘system’ ) AND (table = '%' ) AND active ORDER BY name ASC;


# GET CLUSTERS *
SELECT hostname() as host, * FROM system.clusters   FORMAT Vertical;


# run once for each cluster you have created.
#Top N queries for past 14 days  *
		SELECT
		    hostname() as host,
		    type,
		    event_time,
		    query_duration_ms,
		    substr(query,1,120) as query,
		    read_rows,
		    tables
		FROM  system.query_log
		WHERE (event_time >= (now() - toIntervalDay(30))) AND type='QueryFinish'
		ORDER BY query_duration_ms DESC
		LIMIT 10
		FORMAT VERTICAL

 # run once for each cluster you have created.
 # table information
 SELECT hostname() as host,
  *
  FROM  system.tables
  WHERE database not in ('system', 'INFORMATION_SCHEMA', 'information_schema') ORDER BY database



  ###### Systen Errors #######

# ERRORS ORDER BY COUNT *
SELECT
   hostname() as node,
   name as "Error Name",
    code as "Error Code" ,
    value as "Error Count",
    last_error_time,
    last_error_message
FROM  system.errors
ORDER BY value DESC
LIMIT 25
 FORMAT VERTICAL ;

  # GET ERROR TRACE
  WITH arrayMap(x -> demangle(addressToSymbol(x)), last_error_trace) AS all
  SELECT name, arrayStringConcat(all, '\n') AS res
  FROM system.errors
  LIMIT 1
  SETTINGS allow_introspection_functions=1\G


  ##### Events ######

  # Zookeeper
  SELECT * FROM system.events where event like 'Zoo%' ;

#QUERIES
SELECT
    event AS Event,
    value AS Event_Count,
    substr(description, 1, 72) AS Description
FROM system.events
WHERE event LIKE '%Query%'

#THREDS

SELECT
    event AS Event,
    value AS Event_Count,
    substr(description, 1, 72) AS Description
FROM system.events
WHERE event LIKE 'Thread%'


### Backups
SELECT
 * FROM  system.backups
ORDER BY start_time
LIMIT 10 \G
