CREATE CATALOG hive_catalog WITH (
 'type' = 'hive',
 'default-database' = 'default',
 'hive-conf-dir' = '/opt/hive-conf',
 'hive-version' = '3.1.2'
);

use catalog hive_catalog;