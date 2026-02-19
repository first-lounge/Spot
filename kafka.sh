# kafka개발할때 사용
##!/bin/bash
#
#echo "===기존 컨테이너 종료 및 삭제==="
#docker compose down
#
#echo "===Order,Payment 서비스 빌드==="
#(cd spot-order && ./gradlew bootJar -x test)
#(cd spot-payment && ./gradlew bootJar -x test)
#
#echo "===Order,Payment 빌드 및 시작==="
#docker compose up --build

#!/bin/bash
set -e # 에러 발생 시 즉시 중단

echo "=== 선택적 컨테이너 종료 (Order, Payment, Temporal) ==="
docker compose stop spot-order spot-payment
docker compose rm -f spot-order spot-payment

echo "=== 핵심 서비스 빌드 (Order, Payment) ==="
(cd spot-order && ./gradlew clean bootJar -x test)
(cd spot-payment && ./gradlew clean bootJar -x test)

docker compose up --build -d spot-order spot-payment