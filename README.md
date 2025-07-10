# Flink_POC
**A POC on flink real time streaming with kafka topics and hive tables (support with iceberg also available)**


## Hive Metastore

- A New addition of hive metastore have been added
- A container named hive mestarore will be created
- A postgres service container also will be created which acts as a backend for hive metastore
- Hive mestaore configurations needed to created (which is created in hive-conf/hive-site.xml and mounted to respective conatiners)


## Create build & Containers
- docker-compose build --no-cache
- docker-compose up -d


### Start Flink Sql Client
```bash
docker exec -it flink-jobmanager bash
```

```bash
/opt/flink/bin/sql-client.sh -i sql-client-intialization.sql
```


### Ensure Hive Catalog can be accessed by sql-client
```sql
show catalogs;
show current catalog;
create database hive_new;
show databases;
```


### Create Source Table From Kafka Source Topic (added proctime column to support processing time temporal join)
```sql
CREATE TABLE if not exists ordersSource_v6 (
  product_id STRING,
  user_name string,
  proctime AS Proctime()
) WITH (
  'connector' = 'kafka',
  'topic' = 'mytopic_new_v6',
  'properties.bootstrap.servers' = 'kafka:9092',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json'
);

**Ensure Table is streaming**
SELECT * FROM user_table_v6;
```


### In Another Terminal, Start Spark-sql in spark-hive client container

**Steps**

1. docker exec -it spark-hive-client bash
2. once inside terminal, perform this cmd to start spark-sql shell with hive catalog: /opt/bitnami/spark/bin/spark-sql --hiveconf hive.metastore.uris=thrift://hive-metastore:9083
3. ensure its working by using cmd: show databases; (the database hive_new should reflect here)
4. once ensured, do: use hive_new;


### Create hive batch table
```sql
CREATE TABLE if not exists hive_test_table_new_v6 (
  product_id STRING,
  product_name STRING,
  unit_price DECIMAL(10, 4),
  pv_count BIGINT,
  like_count BIGINT,
  comment_count BIGINT,
  update_time STRING,
  update_user STRING
) 
STORED AS PARQUET 
LOCATION '/opt/warehouse/hive_new/hive_test_table_new_v6'
PARTITIONED BY (
    create_time   STRING
);
```


### Insert hive batch table

1. Before Inserting, we need to provide permission for the path we have created with the table
2. For that, Open a separate spark-sql-hive-client by
```bash
docker exec -u root -it spark-hive-client bash
```
3. In that new terminal, give permission by
```bash
chmod 777 -R /opt/warehouse/hive_new/
```
4. Now Switch back to old spark terminal, and do

```sql
INSERT INTO hive_test_table_new_v6 PARTITION (create_time='create_time_1') VALUES ('product_id_11', 'product_name_11', 1.2345, 100, 50, 20, '2023-11-25 02:10:58', 'update_user_1');
```

### Create Sink Table with kafka connector

Now go to flink sql terminal and,

```sql
CREATE TABLE print_kafka_v6 (
  product_id STRING,
  user_name STRING,
  product_name STRING,
  unit_price DECIMAL(10, 4),
  pv_count BIGINT,
  like_count BIGINT,
  comment_count BIGINT,
  update_time STRING,
  update_user STRING,
  create_time STRING
) WITH (
  'connector' = 'kafka',
  'topic' = 'mytopic_sink_v6',
  'properties.bootstrap.servers' = 'kafka:9092',
  'format' = 'json',
  'scan.startup.mode' = 'earliest-offset'
);
``` 




### Insert into sink table
```sql
insert into print_kafka_v6
select
  orders.product_id,
  orders.user_name,
  dim.product_name,
  dim.unit_price,
  dim.pv_count,
  dim.like_count,
  dim.comment_count,
  dim.update_time,
  dim.update_user,
  dim.create_time
from ordersSource_v6 orders
join hive_test_table_new_v6 /*+ OPTIONS('streaming-source.enable'='true',
   'streaming-source.partition.include' = 'latest', 'streaming-source.monitor-interval' = '15 s') */     
   for system_time as of orders.proctime as dim on orders.product_id = dim.product_id;
```

## Testing The Theory

### Create a source topic producer

- Open a new terminal and start producing to the source topic

```bash 
/usr/bin/kafka-console-producer --bootstrap-server localhost:9092 --topic mytopic_new_v6
```

produce this record:

```bash
{"product_id": "product_id_11", "user_name": "nametest"}
```

### Create a console consumer for source topic

```bash
/usr/bin/kafka-console-consumer --bootstrap-server localhost:9092 --topic mytopic_new_v6 --from-beginning
```

### Create a console consumer for sink topic (which is already streaming by the job)

```bash
/usr/bin/kafka-console-consumer --bootstrap-server localhost:9092 --topic mytopic_sink_v6 --from-beginning
```

The record we put, should join here and should be received by the sink consumer.


### Test latest partition theory

produce a new message to source topic

```bash
{"product_id": "product_id_12", "user_name": "nametest"}
```

Now go back to spark-sql-client terminal and do

```sql
INSERT INTO hive_test_table_new_v6 PARTITION (create_time='create_time_2') VALUES ('product_id_12', 'product_name_12', 1.2345, 100, 50, 20, '2023-11-25 02:10:58', 'update_user_1');
```

now come back to sink topic consumer, the record with product_id_12 we produced before should not reflect here.

now again produce these messages to source topic,

```bash
{"product_id": "product_id_12", "user_name": "namee2"}
{"product_id": "product_id_11", "user_name": "namee1"}
```

now in sink, only 12 should reflect and not 11

This is happening because the latest partition is fetched from hive table, and based on processing time join is happening