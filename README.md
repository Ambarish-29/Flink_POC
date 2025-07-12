# Flink_POC
**A POC on flink real time streaming with kafka topics, schema registry and iceberg table**

## Create Containers
- docker-compose build --no-cache
- docker-compose up -d


## Execute the Python script to produce the data as per the defined schema
python avro_producer.py

## Verify the schema registry by using UI or CLI

Schema Registry URL: http://localhost:8000/

CLI:
curl http://localhost:8084/subjects
curl http://localhost:8084/subjects/source_topic-value/versions/latest
curl http://localhost:8084/subjects/source_topic-value/versions
curl http://localhost:8084/schemas/ids/1


### Start Flink Sql Client
- docker exec -it flink-jobmanager bash
- /opt/flink/bin/sql-client.sh


### Create Source Table From Kafka Source Topic
CREATE TABLE user_table (
  id BIGINT,
  username STRING,
  email STRING,
  country STRING,
  created_time STRING,
  proc_time as PROCTIME()
) WITH (
  'connector' = 'kafka',
  'topic' = 'source_topic',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'avro-confluent',
  'avro-confluent.schema-registry.url' = 'http://schema-registry:8084'
);

**Ensure Table is streaming**
- SELECT * FROM user_table;


### Create Transformed View from source table

CREATE VIEW transformed_users AS
SELECT
  id,
  CASE
WHEN id % 2 = 0 THEN 'even_id' ELSE 'odd_id' END AS id_check,
  username,
  email,
  country,
  CAST(TO_TIMESTAMP(created_time) AS TIMESTAMP_LTZ(3)) AS register_time_ts,
  CURRENT_TIMESTAMP AS event_vw_ts,
  proc_time
FROM user_table;


### Create Sink Table with kafka connector
CREATE TABLE user_sink (
  id BIGINT,
  id_check STRING,
  username STRING,
  city STRING,
  country STRING,
  register_time_ts TIMESTAMP(3),
  event_vw_ts TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_transformed',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'user_sink_group',
  'format' = 'avro-confluent',
  'avro-confluent.schema-registry.url' = 'http://schema-registry:8084'
);


### create a iceberg catalog
CREATE CATALOG iceberg_hadoop WITH (
   'type' = 'iceberg',
   'catalog-type' = 'hadoop',
  'warehouse' = 'file:///opt/warehouse'
);


**switch to iceberg catalog**
- USE CATALOG iceberg_hadoop;


### create iceberg batch table
CREATE TABLE iceberg_hadoop.user_batch_data (
  country STRING,
  city STRING
) WITH (
  'connector' = 'filesystem',
  'path' = 'file:///opt/warehouse/user_batch_data',
  'format' = 'parquet',
  'streaming' = 'true',
  'monitor-interval' = '10s',
  'streaming-starting-strategy' = 'TABLE_SCAN_THEN_INCREMENTAL'
);


### Insert values in iceberg table
INSERT INTO iceberg_hadoop.user_batch_data VALUES ('India', 'Chennai');


**switch to flink catalog**
- use catalog default_catalog;


### Create a view to join transformed flink view and iceberg batch table
CREATE VIEW enriched_user_info AS
SELECT
  a.id,
  a.id_check,
  a.username,
  b.city,
  a.country,
  a.register_time_ts,
  a.event_vw_ts
FROM transformed_users as a
JOIN iceberg_hadoop.iceberg_hadoop.user_batch_data as b
ON a.country = b.country;


### Insert the data from final view to sink topic table
INSERT INTO user_sink
SELECT * FROM enriched_user_info;


### Ensure working by having two console consumers (one for source, one for final output)
docker exec -it connect

kafka-avro-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic source_topic \
  --from-beginning \
  --property schema.registry.url=http://schema-registry:8084

kafka-avro-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic user_transformed \
  --from-beginning \
  --property schema.registry.url=http://schema-registry:8084