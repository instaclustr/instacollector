CREATE TABLE IF NOT EXISTS  demo.server_settings
(
    `name` String,
    `value` String,
    `default` String,
    `changed` UInt8,
    `description` String,
    `type` String,
    `changeable_without_restart` Enum8('No' = 0, 'IncreaseOnly' = 1, 'DecreaseOnly' = 2, 'Yes' = 3),
    `is_obsolete` UInt8
)
ENGINE = MergeTree
ORDER BY name
COMMENT 'Contains a list of all server-wide settings (which are effective only on server startup and usually cannot be modified at runtime), their current and default values along with descriptions.'
