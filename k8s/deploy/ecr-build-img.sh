#!/bin/bash
set -euo pipefail

# 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="ap-northeast-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Colors for output
RED='\033[1;31m'
PURPLE='\033[95m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

log_warn() {
    echo -e "${YELLOW}[WARN] ⚠️ ${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR] ❌ ${NC} $1"
}

log_info() {
    echo -e "${PURPLE}[INFO] ☑️ ${NC} $1"
}

# ECR 로그인
log_info "AWS ECR 로그인을 진행합니다..."

aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# Docker 이미지 빌드 및 Push
log_info "Docker 이미지 빌드와 ECR Push를 시작합니다..."

log_info "Kafka Connect with Debezium 빌드를 시작합니다..."

docker build -t "${ECR_REGISTRY}/spot-kafka-connect:3.4.0" "${BASE_DIR}/../overlays/dev/infra/kafka/"

docker push "${ECR_REGISTRY}/spot-kafka-connect:3.4.0"

SERVICES=("gateway" "user" "store" "order" "payment")

for service in "${SERVICES[@]}"; do
    log_info "Building ${service}..."

    SERVICE_DIR="${BASE_DIR}/../../spot-${service}"

    (cd "${SERVICE_DIR}" && ./gradlew bootJar -x test)

    docker build -t "${ECR_REGISTRY}/spot-dev-${service}:latest" "${SERVICE_DIR}"

    docker push "${ECR_REGISTRY}/spot-dev-${service}:latest"

    log_info "spot-${service} 이미지 Push 성공!"
done

log_info "모든 Spot 서비스의 이미지 빌드 및 Push가 완료되었습니다!"