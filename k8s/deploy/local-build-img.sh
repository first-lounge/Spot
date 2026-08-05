#!/bin/bash
set -euo pipefail

# 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_NAME="spot-registry.localhost"
REGISTRY_PORT="5000"

# output 색상
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
MINI=false

case "${1:-}" in
    --mini)
        MINI=true ;;
    "")              ;;
    *) log_error "알 수 없는 옵션: $1"; exit 1 ;;
esac

is_port_open() {
    (echo > /dev/tcp/127.0.0.1/"$REGISTRY_PORT") 2>/dev/null
}

if [[ "$MINI" == true ]]; then
    # 기존 터널 종료
    if is_port_open; then
        log_warn "이미 ${REGISTRY_PORT} 포트가 사용 중입니다. 기존 SSH 터널을 종료합니다..."
        taskkill //F //IM ssh.exe 2>/dev/null || true
        sleep 2
    fi

    # ssh 포트 포워딩
    log_info "미니PC 레지스트리로 포트 포워딩을 시작합니다..."
    ssh -f -N -o ExitOnForwardFailure=yes -L ${REGISTRY_PORT}:localhost:${REGISTRY_PORT} mini-pc
    log_info "SSH 터널링 성공!"

    log_info "미니PC Docker 레지스트리로 이미지 빌드를 시작합니다..."
else
    log_info "로컬 Docker 레지스트리로 이미지 빌드를 시작합니다..."
fi

SERVICES=("spot-gateway" "spot-user" "spot-store" "spot-order" "spot-payment")

for service in "${SERVICES[@]}"; do
    log_info "Building $service..."

    SERVICE_DIR="$BASE_DIR/../../$service"

    (cd "$SERVICE_DIR" && ./gradlew bootJar -x test)
    
    docker build -t "$REGISTRY_NAME:$REGISTRY_PORT/$service:latest" "$SERVICE_DIR"

    n=0
    PUSH_SUCCESS=false
    until [ $n -ge 3 ]; do
        if docker push "$REGISTRY_NAME:$REGISTRY_PORT/$service:latest"; then
            PUSH_SUCCESS=true
            break
        fi
        n=$((n+1))
        log_warn "$service 이미지 Push 실패. 재시도 ($n/3)..."
        sleep 2
    done

    if [ "$PUSH_SUCCESS" = false ]; then
        log_error "$service 이미지 Push에 실패했습니다."
        if [[ "$MINI" == true ]]; then
            taskkill //F //IM ssh.exe 2>/dev/null || true
        fi
        exit 1
    fi

    log_info "$service 이미지 Push 성공!"
done

log_info "모든 Spot 서비스의 이미지 빌드 및 Push가 완료되었습니다!"

if [[ "$MINI" == true ]]; then
    log_info "백그라운드로 실행한 터미널을 종료합니다."
    taskkill //F //IM ssh.exe 2>/dev/null || true
fi
