from confluent_kafka import avro
from confluent_kafka.avro import AvroProducer
from faker import Faker
import datetime
import time

# Initialize Faker
faker = Faker()

# Kafka and Schema Registry configs
topic = 'source_topic_v7'

# Load Avro schema
value_schema = avro.load('./schemas/user_event.avsc')

producer_config = {
    'bootstrap.servers': 'localhost:9092',
    'schema.registry.url': 'http://localhost:8084',
    'security.protocol': 'PLAINTEXT'
}

# Initialize AvroProducer
producer = AvroProducer(
    producer_config, 
    default_value_schema=value_schema
    )

event_id = 1

try:
    while True:
        # Generate fake data
        event = {
            "id": event_id,
            "username": faker.user_name(),
            "email": faker.email(),
            "country": faker.country(),
            "created_time": datetime.datetime.utcnow().isoformat()
        }

        # Produce to Kafka
        producer.produce(topic=topic, value=event)
        producer.flush()

        print(f"[{event_id}] Sent: {event}")
        event_id += 1

        time.sleep(5)  # wait 2 seconds
except KeyboardInterrupt:
    print("\nStopped.")
