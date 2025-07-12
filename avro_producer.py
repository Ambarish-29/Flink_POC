from confluent_kafka import avro
from confluent_kafka.avro import AvroProducer
from faker import Faker
from datetime import datetime, timezone
import random
import time

# Initialize Faker
faker = Faker()

# Kafka and Schema Registry configs
topic = 'source_topic'

# Load Avro schema
value_schema = avro.load('./schemas/user_event.avsc')

producer_config = {
    'bootstrap.servers': 'localhost:29092',
    'schema.registry.url': 'http://localhost:8084',
    'security.protocol': 'PLAINTEXT'
}

# Initialize AvroProducer
producer = AvroProducer(
    producer_config, 
    default_value_schema=value_schema
    )

event_id = 1

allowed_countries = ["USA", "India", "Germany", "UAE"]

try:
    while True:
        # Generate fake data
        event = {
            "id": event_id,
            "username": faker.user_name(),
            "email": faker.email(),
            "country": random.choice(["USA", "India", "Germany", "UAE"]),
            "created_time": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S.%f')
        }

        # Produce to Kafka
        producer.produce(topic=topic, value=event)
        producer.flush()

        print(f"[{event_id}] Sent: {event}")
        event_id += 1

        time.sleep(5)  # wait 2 seconds
        
except KeyboardInterrupt:
    print("\nStopped.")
