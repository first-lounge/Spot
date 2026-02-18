#!/bin/sh

TARGET_URL=${CONNECT_URL:-"http://connect1:8083"}

echo "Waiting for Kafka Connect at $TARGET_URL..."

until [ $(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL") -eq 200 ]; do
  echo "Connect is not ready yet... (waiting 3s)"
  sleep 3
done

echo " Kafka Connect is UP. Starting registration..."

for file in /configs/*.json; do
  connector_name=$(jq -r '.name' "$file")
  config_body=$(jq -c '.config' "$file")

  echo "Processing Connector: $connector_name"
  response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
       -H "Content-Type: application/json" \
       -d "$config_body" \
       "$TARGET_URL/connectors/$connector_name/config")

  if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
    echo "Successfully registered/updated: $connector_name"
  else
    echo "Failed to register $connector_name (HTTP Status: $response)"
  fi
done

echo "ALL connectors have been processed!"