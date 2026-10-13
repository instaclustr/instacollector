# Cluster
SELECT
cluster,host_name, host_address, shard_num, shard_name, shard_weight, replica_num,
errors_count, slowdowns_count,estimated_recovery_time
FROM system.clusters;

# Quotas
SELECT * FROM system.quotas;

# Replicas
SELECT
    database,
    table,
    is_leader,
    is_readonly,
    is_session_expired,
    future_parts,
    parts_to_check,
    columns_version,
    queue_size,
    inserts_in_queue,
    merges_in_queue,
    log_max_index,
    log_pointer,
    total_replicas,
    active_replicas
FROM system.replicas

# Problem replicas
SELECT
    database,
    table,
    is_leader,
    is_readonly,
    is_session_expired,
    future_parts,
    parts_to_check,
    columns_version,
    queue_size,
    inserts_in_queue,
    merges_in_queue,
    log_max_index,
    log_pointer,
    total_replicas,
    active_replicas
FROM system.replicas
WHERE
       is_readonly
    OR is_session_expired
    OR future_parts > 20
    OR parts_to_check > 10
    OR queue_size > 20
    OR inserts_in_queue > 10
    OR log_max_index - log_pointer > 10
    OR total_replicas < 2
    OR active_replicas < total_replicas

# Number of Active Parts
SELECT
    active,
    count() AS part_count,
    formatReadableSize(max(bytes_on_disk)) AS max_part_size
FROM system.parts
GROUP BY active
ORDER BY part_count DESC ;

SELECT
    partition,
    count() AS part_count,
    formatReadableSize(max(bytes_on_disk)) AS max_part_size,
    formatReadableQuantity (sum(marks)) as marks
FROM system.parts
GROUP BY partition
ORDER BY partition DESC ;

* List All partitions NOT NEEDED
SELECT hostname() as Host,
  substr(table, 1, 22) as table,
    partition ,
    name,
    part_type,
    formatReadableQuantity(rows) as rows, 
    formatReadableQuantity (marks) as marks,
    formatReadableSize(bytes_on_disk) as bytes_on_disk
FROM system.parts
WHERE active=1 ;

# Number of Partitions per user table
SELECT
  substr(p.table, 1, 50) as table,
  uniq(p.partition) as partitions, 
  count(*) as parts,
  formatReadableQuantity(sum(rows)) AS rows,
      formatReadableQuantity(sum(marks)) AS marks,
      formatReadableSize(sum(bytes_on_disk)) AS bytes_on_disk
FROM  system.parts p JOIN  system.tables t ON p.table=t.table
WHERE active=1 AND lower(p.database)  NOT IN ( 'system', 'information_schema')
GROUP BY table
ORDER BY table DESC ;

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
FROM  system.disks ;

# List tables by DB
SELECT
    hostname() AS Host,
    db.name,
    tbl.name,
    tbl.partition_key
FROM system.databases AS db
INNER JOIN system.tables AS tbl ON db.name = tbl.database
WHERE lower(db.name) NOT IN ('system', 'information_schema') ;

#  Dictionaries
SELECT database, name, create_table_query from system.tables where lower(engine)='dictionary'  FORMAT VERTICAL ;

# Projections
SELECT * FROM system.projections   FORMAT VERTICAL ;

#  Table information
SELECT
    database,
    `table`,
    create_table_query,
    engine_full,
    primary_key,
    sorting_key,
    partition_key,
    storage_policy,
    as_select
FROM system.tables
WHERE lower(database) NOT IN ('system', 'information_schema')
ORDER BY database ASC
FORMAT VERTICAL ;

# Tables by database
SELECT
    database,
    count(*) as NTables,
    formatReadableQuantity(sum(total_rows)) AS readabletotal_rows,
    formatReadableSize(sum(total_bytes)) AS total_bytes,
    formatReadableSize(sum(total_bytes_uncompressed)) AS total_bytes_uncompressed,
    sum(active_parts) as active_parts
FROM system.tables
WHERE  lower(database) != 'information_schema')
GROUP BY database;

SELECT
    database,
    name,
    total_rows,
    formatReadableQuantity(total_rows) AS readabletotal_rows,
    formatReadableSize(total_bytes) AS total_bytes,
    formatReadableSize(total_bytes_uncompressed) AS total_bytes_uncompressed,
    parts,
    active_parts
FROM system.tables
WHERE (engine_full NOT LIKE 'System%') AND (lower(database) != 'information_schema') ;

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
FROM  system.data_skipping_indices
FORMAT VERTICAL;

# Table column size
SELECT
    database,
    table,
    column,
    formatReadableSize(sum(column_data_compressed_bytes) AS size) AS compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes) AS usize) AS uncompressed,
    round(usize / size, 2) AS compr_ratio,
    sum(rows) rows_cnt,
    round(usize / rows_cnt, 2) avg_row_size
FROM system.parts_columns
WHERE (active = 1) AND (database <> 'system') AND (table LIKE '%')
GROUP BY
    database,
    table,
    column
ORDER BY
    database ASC,
    `table` ASC,
    column ASC,
    size ASC ;

#  Changed Settings
SELECT
    hostname() AS host,
    name AS Parameter,
    tier,
    value,
    default,
    changed
FROM system.settings
WHERE changed
ORDER BY name ASC ;

SELECT
    hostname() as host,
    name,
    value,
    default,
    changed
FROM system.server_settings
WHERE changed

# Parts per Database
SELECT
  substr(p.table, 1, 22) as table,
  uniq(partition) as partition, count(*) as parts
FROM system.parts p JOIN system.tables t ON p.table=t.table
WHERE active=1 AND p.database <> 'system'
GROUP BY     table
ORDER BY partition DESC ;

 # Active parts user tables
 SELECT
     hostname() AS host,
    concat(database, '.', table) as table,
    partition_id,
    count() as num_parts
FROM system.parts
WHERE active AND lower(database) = 'system'
GROUP BY
    database,
    table,
    partition_id ;

# Top N queries for past 14 days  *
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
		FORMAT VERTICAL ;

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

# Query Events
SELECT
    event AS Event,
    value AS Event_Count,
    formatReadableQuantity(Event_Count) AS Hu_Event_Count,
    substr(description, 1, 72) AS Description
FROM system.events
WHERE lower(event) LIKE '%query%'
ORDER BY Event_Count ASC ;

# Thread Events
SELECT
    event AS Event,
    value AS Event_Count,
     formatReadableQuantity(Event_Count) AS Hu_Event_Count,
    substr(description, 1, 72) AS Description
FROM system.events
WHERE event LIKE 'Thread%' ;

### Backups
SELECT
 * FROM  system.backups
ORDER BY start_time
LIMIT 10 ;
 

 