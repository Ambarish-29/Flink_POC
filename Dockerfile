# -----------------------------
# Dockerfile (Flink + Iceberg + Hadoop)
# -----------------------------
FROM flink:1.17.1-scala_2.12

USER root

RUN apt-get update && apt-get install -y wget

ENV HADOOP_VERSION=3.3.6
ENV ICEBERG_VERSION=1.3.0
ENV FLINK_VERSION=1.17.1
ENV KAFKA_VERSION=3.2.3


# Only download and install Hadoop if not already present
RUN if [ ! -d "/opt/hadoop-${HADOOP_VERSION}" ]; then \
      wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
      tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ && \
      ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
      rm hadoop-${HADOOP_VERSION}.tar.gz; \
    fi

# # Copy essential Hadoop JARs into Flink lib directory
RUN cp /opt/hadoop/share/hadoop/common/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/common/lib/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/hdfs/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/hdfs/lib/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/mapreduce/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/yarn/*.jar /opt/flink/lib/ && \
    cp /opt/hadoop/share/hadoop/yarn/lib/*.jar /opt/flink/lib/ && \
    rm -f /opt/flink/lib/commons-cli-*.jar

# # Download Iceberg Flink runtime JAR
RUN wget -nc -P /opt/flink/lib https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.17/${ICEBERG_VERSION}/iceberg-flink-runtime-1.17-${ICEBERG_VERSION}.jar

# Download Flink Kafka Connector JARs
# Download Flink Kafka Connector JARs
RUN wget -nc -P /opt/flink/lib https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka/${FLINK_VERSION}/flink-connector-kafka-${FLINK_VERSION}.jar  && \
    wget -nc -P /opt/flink/lib https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${FLINK_VERSION}/flink-connector-kafka-${FLINK_VERSION}.jar && \
    wget -nc -P /opt/flink/lib https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_VERSION}/kafka-clients-${KAFKA_VERSION}.jar

USER flink