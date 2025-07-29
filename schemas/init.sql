--IN PROGRESS
CREATE TABLE csf_log_record ( 
	acct_1_nbr STRING,
	pos_merch_type STRING,
	amount_auth DOUBLE,
	proc_time as PROCTIME()
) WITH ('connector' = 'kafka', 'topic' = 'log_record', 'properties.bootstrap.servers' = 'kafka:9092', 'scan.startup.mode' = 'earliest-offset', 'format' = 'avro-confluent', 'avro-confluent.schema-registry.url' = 'http://schema-registry:8084');

CREATE TEMPORARY TABLE new_cust_base (
  rim_no BIGINT,
  acct_no BIGINT
) WITH (
  'connector' = 'filesystem',
  'path' = 'file:///opt/warehouse/data/cust_base_new.csv',
  'format' = 'csv',
  'csv.ignore-parse-errors' = 'true',
  'csv.ignore-first-line' = 'true'
);

CREATE CATALOG iceberg_hadoop WITH ( 'type' = 'iceberg', 'catalog-type' = 'hadoop', 'warehouse' = 'file:///opt/warehouse' );

USE CATALOG iceberg_hadoop;


DROP TABLE iceberg_hadoop.new_cust_base;
CREATE TABLE iceberg_hadoop.new_cust_base (
  rim_no BIGINT,
  acct_no BIGINT
) 
WITH ( 'connector' = 'filesystem', 'path' = 'file:///opt/warehouse/data/new_cust_base', 'format' = 'parquet', 'streaming' = 'true', 'monitor-interval' = '10s', 'streaming-starting-strategy' = 'TABLE_SCAN_THEN_INCREMENTAL');




DROP TABLE iceberg_hadoop.new_cust_base;
CREATE TABLE iceberg_hadoop.new_cust_base (
  rim_no BIGINT,
  acct_no BIGINT
) 
WITH ( 'connector' = 'filesystem', 'path' = 'file:///opt/warehouse/data/new_cust_base', 'format' = 'parquet');



INSERT INTO iceberg_hadoop.new_cust_base SELECT * FROM default_catalog.default_database.new_cust_base;





DROP TABLE IF EXISTS iceberg_hadoop.momentai_airline_booked_dc;
CREATE TABLE iceberg_hadoop.momentai_airline_booked_dc WITH ( 'connector' = 'filesystem', 'path' = 'file:///opt/warehouse/data/momentai_airline_booked_dc', 'format' = 'parquet', 'streaming' = 'true', 'monitor-interval' = '10s', 'streaming-starting-strategy' = 'TABLE_SCAN_THEN_INCREMENTAL') AS
SELECT
  TRIM(SUBSTRING(acct_1_nbr, CHAR_LENGTH(TRIM(acct_1_nbr)) - 7 + 1)) AS acct_1_nbr,
  amount_auth,
  CASE
    WHEN pos_merch_type='3026' THEN 'emirates_airlines'
    WHEN pos_merch_type='3034' THEN 'etihad_airlines'
    ELSE 'other_airlines'
  END AS Airline_flag
FROM default_catalog.default_database.csf_log_record
  WHERE (CAST(pos_merch_type AS BIGINT) BETWEEN 3000 AND 3299);


DROP TABLE IF EXISTS iceberg_hadoop.momentai_airline_booked_dc;
CREATE TABLE iceberg_hadoop.momentai_airline_booked_dc WITH ( 'connector' = 'filesystem', 'path' = 'file:///opt/warehouse/data/momentai_airline_booked_dc', 'format' = 'parquet') AS
SELECT
  TRIM(SUBSTRING(acct_1_nbr, CHAR_LENGTH(TRIM(acct_1_nbr)) - 7 + 1)) AS acct_1_nbr,
  amount_auth,
  CASE
    WHEN pos_merch_type='3026' THEN 'emirates_airlines'
    WHEN pos_merch_type='3034' THEN 'etihad_airlines'
    ELSE 'other_airlines'
  END AS Airline_flag
FROM default_catalog.default_database.csf_log_record
  WHERE (CAST(pos_merch_type AS BIGINT) BETWEEN 3000 AND 3299);


DROP TABLE IF EXISTS iceberg_hadoop.momentai_card_recommendation;
CREATE TABLE iceberg_hadoop.momentai_card_recommendation WITH ( 'connector' = 'filesystem', 'path' = 'file:///opt/warehouse/data/momentai_card_recommendation', 'format' = 'parquet') AS
SELECT 
	* 
FROM 
	(
	SELECT 
		* 
	FROM iceberg_hadoop.momentai_airline_booked_dc
	) a 
LEFT JOIN 
	(
	SELECT 
		* 
	FROM iceberg_hadoop.new_cust_base
	)b
ON CAST(a.acct_1_nbr AS BIGINT)=b.acct_no;