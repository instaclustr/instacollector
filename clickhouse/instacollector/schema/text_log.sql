CREATE TABLE IF NOT EXISTS demo.text_log
(
    `hostname` LowCardinality(String) COMMENT 'Hostname of the server executing the query.',
    `event_date` Date COMMENT 'Date of the entry.',
    `event_time` DateTime COMMENT 'Time of the entry.',
    `event_time_microseconds` DateTime64(6) COMMENT 'Time of the entry with microseconds precision.',
    `thread_name` LowCardinality(String) COMMENT 'Name of the thread from which the logging was done.',
    `thread_id` UInt64 COMMENT 'OS thread ID.',
    `level` Enum8('Fatal' = 1, 'Critical' = 2, 'Error' = 3, 'Warning' = 4, 'Notice' = 5, 'Information' = 6, 'Debug' = 7, 'Trace' = 8, 'Test' = 9) COMMENT 'Entry level. Possible values: 1 or \'Fatal\', 2 or \'Critical\', 3 or \'Error\', 4 or \'Warning\', 5 or \'Notice\', 6 or \'Information\', 7 or \'Debug\', 8 or \'Trace\'.',
    `query_id` String COMMENT 'ID of the query.',
    `logger_name` LowCardinality(String) COMMENT 'Name of the logger (e.g., DDLWorker).',
    `message` String COMMENT 'The message itself.',
    `revision` UInt32 COMMENT 'ClickHouse revision.',
    `source_file` LowCardinality(String) COMMENT 'Source file from which the logging was done.',
    `source_line` UInt64 COMMENT 'Source line from which the logging was done.',
    `message_format_string` LowCardinality(String) COMMENT 'A format string that was used to format the message.',
    `value1` String COMMENT 'Argument 1 that was used to format the message.',
    `value2` String COMMENT 'Argument 2 that was used to format the message.',
    `value3` String COMMENT 'Argument 3 that was used to format the message.',
    `value4` String COMMENT 'Argument 4 that was used to format the message.',
    `value5` String COMMENT 'Argument 5 that was used to format the message.',
    `value6` String COMMENT 'Argument 6 that was used to format the message.',
    `value7` String COMMENT 'Argument 7 that was used to format the message.',
    `value8` String COMMENT 'Argument 8 that was used to format the message.',
    `value9` String COMMENT 'Argument 9 that was used to format the message.',
    `value10` String COMMENT 'Argument 10 that was used to format the message.'
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, event_time)
SETTINGS index_granularity = 8192
COMMENT 'Contains logging entries which are normally written to a log file or to stdout.\n\nIt is safe to truncate or drop this table at any time.'
