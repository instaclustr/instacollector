CREATE DATABASE IF NOT EXISTS demo

CREATE TABLE demo.asynchronous_metric_log AS system.asynchronous_metric_log;
CREATE TABLE demo.error_log as system.error_log
CREATE TABLE demo.metric_log as system.metric_log;
CREATE TABLE demo.query_log AS system.query_log ;
CREATE TABLE demo.query_metric_log AS system.query_metric_log;

