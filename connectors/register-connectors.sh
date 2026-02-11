#!/bin/sh

TARGET_URL=${CONNECT_URL:-"http://connect:8083"}

echo "Waiting for Kafka Connect..."
while [ $(curl -s -o /dev/null -w "%{http_code}" $TARGET_URL) -ne 200 ]; do
  sleep 3
done

echo "Registering connectors from /configs..."
for file in /configs/*.json; do
  filename=$(basename "$file")
  echo "Processing $filename..."

  sed -e "s|\${env:DB_HOST}|$DB_HOST|g" \
      -e "s|\${env:SPRING_DATASOURCE_USERNAME}|$SPRING_DATASOURCE_USERNAME|g" \
      -e "s|\${env:SPRING_DATASOURCE_PASSWORD}|$SPRING_DATASOURCE_PASSWORD|g" \
      -e "s|\${env:DB_NAME}|$DB_NAME|g" \
      "$file" > "/tmp/$filename"

  response=$(curl -s -X POST -H "Content-Type: application/json" \
            -d @"/tmp/$filename" \
            $TARGET_URL/connectors)
  echo "Response for $filename: $response"
done

echo "ALL connectors Created"