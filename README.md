# Production Replica Springboot Microservice to send Message through Notification to Customers


# SSL Configurations


## Server Side Certificate Generation

1. Prepare kafka-hosts.txt with this kafka-0 kafka-1 kafka-2 kafka
2. ./generate.sh
3. Mount Respective Certificates in Containers
4. Prepare Necessary Environment Variables

### If DNS Error Came (Said Kafka-2 is not present in certificate name)

1. export KAFKA_HOST=kafka-2
2. cat > san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $KAFKA_HOST
DNS.2 = $KAFKA_HOST.kafka-network
DNS.3 = localhost
EOF
3. keytool -certreq -keystore keystore/kafka-2.server.keystore.jks -alias localhost -file cert-file-kafka-2 -storepass supersecret
4. openssl x509 -req -CA certificate-authority/ca-cert -CAkey certificate-authority/ca-key -in cert-file-kafka-2 -out cert-signed-kafka-2 -days 3650 -CAcreateserial -extfile san.cnf -extensions v3_req
5.  keytool -keystore keystore/kafka-2.server.keystore.jks -alias localhost -import -file cert-signed-kafka-2 -storepass supersecret -keypass supersecret
6. keytool -list -v -keystore keystore/kafka-0.server.keystore.jks -storepass supersecret 



## Client Side Certificate Generation

### Theory

1. Kafka certificates are used by Kafka brokers to prove their identity and to encrypt data when communicating with clients (like your Spring Boot app).
2. Client certificates (used by your Spring app) are different certificates from broker certificates. These certificates prove your app’s identity to Kafka when Kafka requires client authentication.
3. So, you need separate certificates for brokers and for your Spring app (client).
They come from the same Certificate Authority (CA) — which is your "trust certificate" — but the certificates themselves are different.
4. Both brokers and clients share the truststore, which contains the CA certificate(s) to verify each other’s certificates.
5. When SASL_SSL with mutual TLS (mTLS) is used, Kafka broker validates the client cert, and client validates the broker cert using the truststore.
6. Therefore, you must generate separate client certificates for your Spring Boot app to authenticate it properly. You cannot use broker certs as client certs.

### Practical Steps

1. openssl genrsa -out client.key 2048
2. openssl req -new -key client.key -out client.csr -subj "//CN=client1"
3. move the files under certificate authority in kafka setup to the current folder
4. openssl x509 -req -CA ca-cert -CAkey ca-key -CAcreateserial -in client.csr -out client.crt -days 365 -sha256
5. ls to verify that these are present: ca-cert  ca-cert.srl  ca-key  client.crt  client.csr  client.key
6. openssl pkcs12 -export -in client.crt -inkey client.key -out client.keystore.p12 -name kafka-client -CAfile ca-cert -caname root -password pass:supersecret
7. keytool -import -file ca-cert -alias CARoot -keystore client.truststore.jks -storepass supersecret -noprompt
8. Once Certifcates Generated Mention those certificates in application.yml like this

properties:
    security.protocol: SASL_SSL
    sasl.mechanism: PLAIN
    sasl.jaas.config: org.apache.kafka.common.security.plain.PlainLoginModule required username="client" password="client-password";
    ssl.truststore.location: /etc/kafka/secrets/client.truststore.jks
    ssl.truststore.password: supersecret
    ssl.keystore.location: /etc/kafka/secrets/client.keystore.p12
    ssl.keystore.password: supersecret
    ssl.key.password: supersecret


# SASL Configurations

## Server Side Configurations

### Zookeeper

Generate a server side conf with zookeeper_jaas.conf
In docker compose of zookeeper add necessary properties
mount the conf file inside container

### Kafka

Generate a server and client side conf with kafka_server_jaas.conf
Make sure the client properties are uses credentials from zookeeper server properties
In docker compose of kafka add necessary properties
mount the conf file inside container

## Client Side Configurations
Now any client want to connect with kafka or zookeeper need to have the credentials from the server side of the containers

### Springboot client

Since springboot client wants to connect with kafka, we need to explicitely mention this properties there




# Microservice Production Details

We have seen the sasl and ssl above, some other configs mentioned are

generate encrytion
mvn jasypt:encrypt-value "-Djasypt.encryptor.password=letsok" "-Djasypt.plugin.value=YourStrong!Passw0rd"

use that in your application.yml with following properties

jasypt:
  encryptor:
    algorithm: PBEWithMD5AndDES

and pass passwords for decrytion while running the jar from docker compose

example:

compose:

environment:
  JASYPT_ENCRYPTOR_PASSWORD: letsok

dockerfile:

ENTRYPOINT ["sh", "-c", "echo JasyptPassword=$JASYPT_ENCRYPTOR_PASSWORD && java -Djasypt.encryptor.password=$JASYPT_ENCRYPTOR_PASSWORD -Djasypt.encryptor.algorithm=PBEWithMD5AndDES -jar /app.jar"]




