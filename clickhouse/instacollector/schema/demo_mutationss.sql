CREATE TABLE IF NOT EXISTS demo.mutations
(
    `database` String,
    `table` String,
    `mutation_id` String,
    `command` String,
    `create_time` DateTime,
    `block_numbers.partition_id` Array(String),
    `block_numbers.number` Array(Int64),
    `parts_to_do_names` Array(String),
    `parts_to_do` Int64,
    `is_done` UInt8,
    `is_killed` UInt8,
    `latest_failed_part` String,
    `latest_fail_time` DateTime,
    `latest_fail_reason` String,
    `latest_fail_error_code_name` String
)
ENGINE = MergeTree
ORDER BY (database, `table`)
