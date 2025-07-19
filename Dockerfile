# Use OpenJDK 17 image
FROM openjdk:17-jdk-slim

# Copy the built jar file (adjust name if different)
COPY target/whatsapp-kafka-0.0.1-SNAPSHOT.jar app.jar

# Run the jar file
ENTRYPOINT ["java","-jar","/app.jar"]
