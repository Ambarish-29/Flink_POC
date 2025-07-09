# Flink_POC
A POC on flink real time streaming with kafka topics and iceberg tables

docker-compose build --no-cache
docker-compose up -d


create this json in kafkagen-connectors folder (name: users_mock_data.json)

{
  "name": "datagen-json",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "user_actions_json",
    "quickstart": "users",
    "max.interval": 1000,
    "iterations": -1,
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": false
  }
}


curl -X DELETE http://localhost:8083/connectors/datagen-json
cd kafkagen-connectors
curl -X POST -H "Content-Type: application/json" --data @users_mock_data.json http://localhost:8083/connectors
curl http://localhost:8083/connectors/datagen-json/status


docker exec -it flink-jobmanager bash
/opt/flink/bin/sql-client.sh



CREATE TABLE user_table_v6 (
  registertime BIGINT,
  userid STRING,
  regionid STRING,
  gender STRING,
  proc_time as PROCTIME()
) WITH (
  'connector' = 'kafka',
  'topic' = 'source_topic_v6',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true'
);

SELECT * FROM user_table_v6;


CREATE VIEW transformed_users_v6 AS
SELECT
  userid,
  gender,
  regionid,
  TO_TIMESTAMP_LTZ(registertime, 3) AS register_time_ts,
  proc_time,
  CASE
    WHEN gender = 'MALE' THEN 'M'
    WHEN gender = 'FEMALE' THEN 'F'
    ELSE 'O'
  END AS gender_short
FROM user_table_v6;



CREATE TABLE user_sink_v6 (
  userid STRING,
  regionid STRING,
  extra_info STRING
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_transformed_v6',
  'properties.bootstrap.servers' = 'kafka:9092',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true'
);


CREATE CATALOG iceberg_hadoop WITH (
   'type' = 'iceberg',
   'catalog-type' = 'hadoop',
  'warehouse' = 'file:///opt/warehouse'
);


USE CATALOG iceberg_hadoop;

CREATE TABLE iceberg_hadoop.user_metadata_v6 (
  userid STRING,
  extra_info STRING
) WITH (
  'connector' = 'filesystem',
  'path' = 'file:///opt/warehouse/user_metadata_v6',
  'format' = 'parquet',
  'streaming' = 'true',
  'monitor-interval' = '10s',
  'streaming-starting-strategy' = 'TABLE_SCAN_THEN_INCREMENTAL'
);


INSERT INTO iceberg_hadoop.user_metadata_v6 VALUES ('User_4', 'Active User');


use catalog default_catalog;


CREATE VIEW enriched_user_info_v6 AS
SELECT
  t.userid,
  t.regionid,
  m.extra_info
FROM transformed_users_v6 as t
JOIN iceberg_hadoop.iceberg_hadoop.user_metadata_v6 as m
ON t.userid = m.userid;


INSERT INTO user_sink_v6
SELECT * FROM enriched_user_info_v6;


kafka-console-consumer --bootstrap-server kafka:9092 --topic source_topic_v6 --from-beginning

kafka-console-consumer --bootstrap-server kafka:9092 --topic user_transformed_v6 --from-beginning



CREATE TABLE kafka_intermediate_table_v6 (
  userid STRING,
  regionid STRING,
  extra_info STRING
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_transformed_v6',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true'
);









CREATE TABLE user_transformed_sink (
>   userid STRING,
>   gender STRING,
>   regionid STRING,
>   register_time_ts TIMESTAMP_LTZ(3),
>   gender_short STRING
> )
> PARTITIONED BY (regionid);


USE CATALOG default_catalog;


CREATE TABLE kafka_user_transformed (
  userid STRING,
  gender STRING,
  regionid STRING,
  register_time_ts TIMESTAMP_LTZ(3),
  gender_short STRING,
  proc_time TIMESTAMP_LTZ(3),
  WATERMARK FOR proc_time AS proc_time - INTERVAL '5' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_transformed_new',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.fail-on-missing-field' = 'false',
  'json.ignore-parse-errors' = 'true'
);

select * from kafka_user_transformed;


SET execution.checkpointing.interval = '5 min';

USE CATALOG iceberg_hadoop;


CREATE TABLE iceberg_hadoop.user_transformed_sink (
  userid STRING,
  gender STRING,
  regionid STRING,
  register_time_ts TIMESTAMP_LTZ(3),
  gender_short STRING,
  window_start TIMESTAMP_LTZ(3)  -- new column for window start time
) WITH (
  'format-version' = '2',
  'write.format.default' = 'parquet',
  'warehouse' = 'file:///opt/warehouse/user_transformed_sink'
);


INSERT INTO iceberg_hadoop.user_transformed_sink
> SELECT
>   userid,
>   gender,
>   regionid,
>   register_time_ts,
>   gender_short,
>   CAST(NULL AS TIMESTAMP_LTZ(3)) AS window_start  -- since your Iceberg table has this column, set it NULL for now
> FROM default_catalog.default_database.kafka_user_transformed;