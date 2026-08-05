#!/bin/bash
set -euo pipefail

# output 색상
RED='\033[1;31m'
PURPLE='\033[95m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

log_warn() { echo -e "${YELLOW}[WARN] ⚠️ ${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] ❌ ${NC} $1"; }
log_info() { echo -e "${PURPLE}[INFO] ☑️ ${NC} $1"; }

# 기본 경로 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_status() {
    log_info "=== Infra 네임스페이스 Pod ==="
    kubectl get po -n infra
    
    log_info "=== Monitoring 네임스페이스 Pod ==="
    kubectl get po -n monitoring
    
    log_info "=== Spot 네임스페이스 Pod ==="
    kubectl get po -n spot

    log_info "=== 접속 정보 ==="
    echo "Gateway API : http://www.spot"
    echo "Kafka UI    : http://kafka.spot"
    echo "Temporal UI : http://temporal.spot"
    echo "Grafana     : http://grafana.spot"

    log_warn "위 주소는 hosts 파일 등록이 필요합니다:"
    echo "127.0.0.1 www.spot kafka.spot temporal.spot grafana.spot"
}

main() {
    case "${1:-}" in
        # 전체 실행
        "") 
            "${BASE_DIR}/k8s/bootstrap/k3d-cluster-init.sh"
            "${BASE_DIR}/k8s/deploy/local-build-img.sh"
            "${BASE_DIR}/k8s/deploy/deploy-local.sh"
            show_status
            exit 0
            ;;
        
        # Monitoring 네임스페이스만 제외
        --no-monitoring)
            "${BASE_DIR}/k8s/bootstrap/k3d-cluster-init.sh"
            "${BASE_DIR}/k8s/deploy/local-build-img.sh"
            "${BASE_DIR}/k8s/deploy/deploy-local.sh" "$1"
            show_status;
            exit 0
            ;;
        
        # 미니PC 대상: 이미지 빌드(SSH 터널) + 배포 — 노트북에서 실행
        --mini) 
            "${BASE_DIR}/k8s/deploy/local-build-img.sh" "$1"
            "${BASE_DIR}/k8s/deploy/deploy-local.sh" # "--no-monitoring"
            show_status;
            exit 0 
            ;;
        
        # k3d 클러스터만 생성 (미니PC에서 실행) 
        --cluster) "${BASE_DIR}/k8s/bootstrap/k3d-cluster-init.sh"; exit 0  ;;

        # 이미지 빌드 및 푸시만 실행
        --build) "${BASE_DIR}/k8s/deploy/local-build-img.sh"; exit 0 ;;

        # k3d 초기 세팅 (namespace, secret, config, nginx 설치) 
        --bootstrap) "${BASE_DIR}/k8s/deploy/deploy-local.sh" "$1"; exit 0 ;;

        # Infra 네임스페이스만 배포
        --infra) "${BASE_DIR}/k8s/deploy/deploy-local.sh" "$1"; exit 0 ;;

        # Monitoring 네임스페이스만 배포
        --monitoring) "${BASE_DIR}/k8s/deploy/deploy-local.sh" "$1"; exit 0 ;;

        # Spot 네임스페이스만 배포
        --spot) "${BASE_DIR}/k8s/deploy/deploy-local.sh" "$1"; exit 0 ;;

        # 에러 메세지
        *) log_error "알 수 없는 옵션: $1"; exit 1 ;;
    esac
}

main "$@"
