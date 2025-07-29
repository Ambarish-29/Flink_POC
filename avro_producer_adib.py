from confluent_kafka import SerializingProducer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import StringSerializer
from faker import Faker
from decimal import Decimal
import random
import time

faker = Faker()

# --- Common Config ---
schema_registry_conf = {'url': 'http://localhost:8084'}
producer_conf = {
    'bootstrap.servers': 'localhost:29092',
    'key.serializer': StringSerializer('utf_8'),
    'security.protocol': 'PLAINTEXT'
}

schema_registry_client = SchemaRegistryClient(schema_registry_conf)


# --- Helper function ---
def load_schema(path):
    with open(path, 'r') as f:
        return f.read()


# --- Schema Setup ---

schemas = {
    "log_record": {
        "schema": load_schema('./schemas/log_record.avsc'),
        "serializer": None,
        "generate": lambda id: {
            #"acct_1_nbr": faker.bban(),
            "acct_1_nbr": str(faker.random_int(min=100000, max=9999984)),
            #"pos_merch_type": random.choice(['3000', '3299', '3026', '3034', '3538', '5451', '8661', '5812', '5541', '5631', '6540', '8999', '5311', '4789', '7230', '7523', '4225', '6513', '5735', '3692', '7392', '7832', '3812', '5817', '7922', '3009']),
            #"pos_merch_type": str(random.randint(2950, 3350)),
            "pos_merch_type": str(random.randint(3025, 3035)),
            "amount_auth": round(random.uniform(10.0, 99999.99), 2)
        }
    }
}

# --- AvroSerializer for each topic ---
for topic in schemas:
    schemas[topic]["serializer"] = AvroSerializer(
        schema_registry_client,
        schemas[topic]["schema"],
        lambda obj, ctx: obj
    )


# --- Producer and loop ---
producers = {
    topic: SerializingProducer({**producer_conf, 'value.serializer': schemas[topic]['serializer']})
    for topic in schemas
}

event_id = 1

#try:
#    while True:
#        for topic in schemas:
#            data = schemas[topic]["generate"](event_id)
#            producers[topic].produce(topic=topic, key=str(event_id), value=data)
#            producers[topic].flush()
#            print(f"[{event_id}] Sent to {topic}: {data}")
#        event_id += 1
#        time.sleep(5)

MAX_RETRIES = 5

try:
    while True:
        for topic in schemas:
            data = schemas[topic]["generate"](event_id)
            retries = 0
            success = False
            while retries < MAX_RETRIES and not success:
                try:
                    producers[topic].produce(topic=topic, key=str(event_id), value=data)
                    producers[topic].flush()
                    print(f"[{event_id}] Sent to {topic}: {data}")
                    success = True
                except Exception as e:
                    retries += 1
                    print(f"[{event_id}] Failed to send to {topic} (Attempt {retries}/{MAX_RETRIES}): {e}")
                    time.sleep(5)
            if not success:
                print(f"[{event_id}] Giving up on topic '{topic}' after {MAX_RETRIES} retries.")
        event_id += 1
        time.sleep(5)

except KeyboardInterrupt:
    print("Stopped.")
