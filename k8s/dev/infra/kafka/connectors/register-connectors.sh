#!/bin/sh

# 디버깅 모드 활성화
# set -x

TARGET_URL="http://spot-connect-svc:8083/connectors"

echo "Checking connectivity to $TARGET_URL"

while true; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL")

  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "SUCCESS: Kafka Connect is ready!"
    break
  fi

  echo "WAITING: Current status is $HTTP_STATUS. Retrying in 5 seconds..."
  sleep 5
done

echo "Starting connector registration..."
for file in /configs/*.json; do
  [ -f "$file" ] || continue
  filename=$(basename "$file")
  echo "Registering: $filename"

  # 환경변수 치환
  sed -e "s|\${env:DB_HOST}|$DB_HOST|g" \
      -e "s|\${env:SPRING_DATASOURCE_USERNAME}|$SPRING_DATASOURCE_USERNAME|g" \
      -e "s|\${env:SPRING_DATASOURCE_PASSWORD}|$SPRING_DATASOURCE_PASSWORD|g" \
      -e "s|\${env:DB_NAME}|$DB_NAME|g" \
      "$file" > "/tmp/$filename"

  # 등록 요청
  curl -s -X POST -H "Content-Type: application/json" \
       -d @"/tmp/$filename" \
       "$TARGET_URL"
  
  echo "Done: $filename"
done

echo "✅ COMPLETED: All connectors processed."