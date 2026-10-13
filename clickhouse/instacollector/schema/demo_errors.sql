CREATE TABLE IF NOT EXISTS  demo.errors
(
    `name` String,
    `code` Int32,
    `value` UInt64,
    `last_error_time` DateTime,
    `last_error_message` String,
    `last_error_trace` Array(UInt64),
    `remote` UInt8,
    `query_id` String
)
ENGINE = MergeTree
ORDER BY last_error_time
