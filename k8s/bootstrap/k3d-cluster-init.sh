#!/bin/bash
set -euo pipefail

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

# 1. 변수 설정
CLUSTER_NAME="spot-cluster"
REGISTRY_NAME="spot-registry.localhost"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PUBLIC_IP=$(curl -s ifconfig.me)
API_PORT=$K8S_API_PORT

# 2. 설치 여부 확인
log_info "필수 도구 설치 여부를 확인합니다..."
for tool in docker k3d kubectl helm; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "$tool 가 설치되어 있지 않습니다. 설치 후 다시 시도하세요."
        exit 1
    fi
done

# 3. docker 실행 여부 확인
if ! docker info &> /dev/null; then
    log_error "Docker 엔진이 실행 중이 아닙니다. Docker를 먼저 실행하세요."
    exit 1
fi

log_info "k3d 클러스터($CLUSTER_NAME) 구축을 시작합니다..."

# 4. 기존 클러스터 존재 여부 확인 및 삭제
log_info "기존 클러스터 및 레지스트리 정리 중..."
k3d cluster delete "$CLUSTER_NAME" &> /dev/null || true
docker rm -f "k3d-$REGISTRY_NAME" &> /dev/null || true

# 5. 클러스터 생성
log_info "클러스터 생성을 시작합니다..."
CONFIG_FILE="$BASE_DIR/k3d-config.yaml"
REGISTRY_FILE="$BASE_DIR/registries.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "설정 파일이 존재하지 않습니다: $CONFIG_FILE"; exit 1
fi

log_info "레지스트리 설정 파일 생성 중..."
cat <<EOF > "$REGISTRY_FILE"
mirrors:
  "spot-registry.localhost:5111":
    endpoint:
      - "http://host.k3d.internal:5111"
EOF

# 6. 클러스터 생성
export PUBLIC_IP API_PORT
cat "$CONFIG_FILE" | envsubst | k3d cluster create --config - --registry-config "$REGISTRY_FILE"

# 7. 완료 대기 및 확인
log_info "노드 준비 대기 중..."
kubectl wait --for=condition=ready node --all --timeout=180s

# 8. 초기 세팅 네임스페이스 생성
log_info "네임스페이스 생성을 시작합니다..."
for ns in argocd ingress-nginx; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# 9. Ingress Controller 설치
log_info "Ingress-nginx Controller 설치를 시작합니다..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.3/deploy/static/provider/cloud/deploy.yaml

log_info "Ingress Controller Pod가 준비될 때까지 대기합니다..."
sleep 5
kubectl wait --for=condition=ready pod -n ingress-nginx --selector=app.kubernetes.io/component=controller --timeout=120s

echo "--------------------------------------"
log_info "클러스터 구축 및 초기 세팅이 완료되었습니다!"
echo "--------------------------------------"