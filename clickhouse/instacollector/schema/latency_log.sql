CREATE TABLE IF NOT EXISTS demo.latency_log
(
    `hostname` LowCardinality(String) COMMENT 'Hostname of the server executing the query.',
    `event_date` Date COMMENT 'Event date.',
    `event_time` DateTime COMMENT 'Event time.',
    `event_time_microseconds` DateTime64(6) COMMENT 'Event time with microseconds resolution.',
    `LatencyEvent_S3FirstByteReadAttempt1Microseconds` Array(UInt64) COMMENT 'Time of first byte read from S3 storage (attempt 1).',
    `LatencyEvent_S3FirstByteWriteAttempt1Microseconds` Array(UInt64) COMMENT 'Time of first byte write to S3 storage (attempt 1).',
    `LatencyEvent_S3FirstByteReadAttempt2Microseconds` Array(UInt64) COMMENT 'Time of first byte read from S3 storage (attempt 2).',
    `LatencyEvent_S3FirstByteWriteAttempt2Microseconds` Array(UInt64) COMMENT 'Time of first byte write to S3 storage (attempt 2).',
    `LatencyEvent_S3FirstByteReadAttemptNMicroseconds` Array(UInt64) COMMENT 'Time of first byte read from S3 storage (attempt N).',
    `LatencyEvent_S3FirstByteWriteAttemptNMicroseconds` Array(UInt64) COMMENT 'Time of first byte write to S3 storage (attempt N).',
    `LatencyEvent_S3ConnectMicroseconds` Array(UInt64) COMMENT 'Time to connect for requests to S3 storage.',
    `LatencyEvent_DiskS3FirstByteReadAttempt1Microseconds` Array(UInt64) COMMENT 'Time of first byte read from DiskS3 storage (attempt 1).',
    `LatencyEvent_DiskS3FirstByteWriteAttempt1Microseconds` Array(UInt64) COMMENT 'Time of first byte write to DiskS3 storage (attempt 1).',
    `LatencyEvent_DiskS3FirstByteReadAttempt2Microseconds` Array(UInt64) COMMENT 'Time of first byte read from DiskS3 storage (attempt 2).',
    `LatencyEvent_DiskS3FirstByteWriteAttempt2Microseconds` Array(UInt64) COMMENT 'Time of first byte write to DiskS3 storage (attempt 2).',
    `LatencyEvent_DiskS3FirstByteReadAttemptNMicroseconds` Array(UInt64) COMMENT 'Time of first byte read from DiskS3 storage (attempt N).',
    `LatencyEvent_DiskS3FirstByteWriteAttemptNMicroseconds` Array(UInt64) COMMENT 'Time of first byte write to DiskS3 storage (attempt N).',
    `LatencyEvent_DiskS3ConnectMicroseconds` Array(UInt64) COMMENT 'Time to connect for requests to DiskS3 storage.'
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, event_time)
SETTINGS index_granularity = 8192
COMMENT 'Contains history of all latency buckets, periodically flushed to disk.\n\nIt is safe to truncate or drop this table at any time.'
