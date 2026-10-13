CREATE TABLE IF NOT EXISTS demo.metrics
(
    `metric` String,
    `value` Int64,
    `description` String,
    `name` String ALIAS metric
)
ENGINE = MergeTree
ORDER BY metric
COMMENT 'Contains metrics which can be calculated instantly, or have a current value. For example, the number of simultaneously processed queries or the current replica delay. This table is always up to date.'
