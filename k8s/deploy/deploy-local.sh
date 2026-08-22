#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[1;31m'
PURPLE='\033[95m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

log_warn() { echo -e "${YELLOW}[WARN] ⚠️ ${NC} $1"; }
log_error() { echo -e "${RED}[ERROR] ❌ ${NC} $1"; }
log_info() { echo -e "${PURPLE}[INFO] ☑️ ${NC} $1"; }

# 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Namespace & Secret & ConfigMap & nginx-ingress 생성
bootstrap() {
    SECRET_PATH="$BASE_DIR/../base/secret"
    CONFIG_PATH="$BASE_DIR/../overlays/local/config"

    # Namespace
    log_info "네임스페이스 생성을 시작합니다..."

    for ns in ingress-nginx infra monitoring spot; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done

    log_info "네임스페이스 생성을 완료하였습니다...!"

    # Secret & ConfigMap
    if [ ! -f "$SECRET_PATH/.env" ]; then
        log_error ".env 파일을 생성 후 실행해주세요."
        exit 1
    fi

    log_info "ConfigMap과 Secret 생성을 시작합니다..."

    kubectl apply -k "$SECRET_PATH"
    kubectl apply -k "$CONFIG_PATH"

    log_info "ConfigMap과 Secret 생성을 완료하였습니다."
    
    # Ingress Controller 설치
    log_info "Ingress-nginx Controller 설치를 시작합니다..."

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.3/deploy/static/provider/cloud/deploy.yaml

    log_info "Ingress Controller Pod가 준비될 때까지 대기합니다..."
    
    sleep 5
    kubectl wait --for=condition=ready pod -n ingress-nginx --selector=app.kubernetes.io/component=controller --timeout=120s

    log_info "Ingress-nginx Controller 설치를 완료하였습니다...!"
}

# infra 네임스페이스 배포 (Kustomize)
deploy_infra() {
    INFRA_PATH="$BASE_DIR/../overlays/local/infra"

    log_info "Infra 네임스페이스 배포를 시작합니다..."

    kubectl apply -k "$INFRA_PATH"

    # PostgreSQL
    kubectl rollout status sts/postgres -n infra --timeout=180s
    
    # Redis
    kubectl wait --for=condition=available deploy/redis -n infra --timeout=180s

    # Kafka
    kubectl rollout status sts/kafka -n infra --timeout=300s

    # Kafka Connect
    kubectl wait --for=condition=available deploy/spot-connect -n infra --timeout=180s

    # Connector-Register
    kubectl wait --for=condition=complete job/connector-register -n infra --timeout=180s

    # Kafka UI
    kubectl wait --for=condition=available deploy/kafka-ui -n infra --timeout=180s
  
    # Temporal
    kubectl wait --for=condition=available deploy/temporal -n infra --timeout=180s
    kubectl wait --for=condition=available deploy/temporal-ui -n infra --timeout=180s

    log_info "Infra 네임스페이스 배포를 모두 완료하였습니다...!"
}

# monitoring 네임스페이스 배포 (Helm + Kustomize)
deploy_monitoring() {
    MONITORING_PATH="${BASE_DIR}/../overlays/local/monitoring"
    VALUES_FILE="${MONITORING_PATH}/platform/prometheus/values.yaml"

    log_info "Monitoring 네임스페이스 배포를 시작합니다..."

    log_info "Prometheus (kube-prometheus-stack) 설치를 시작합니다..."

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update

    if [ ! -f "$VALUES_FILE" ]; then
        log_error "Prometheus values file not found: $VALUES_FILE"
        exit 1
    fi

    helm upgrade --install prom prometheus-community/kube-prometheus-stack \
        -n monitoring \
        -f "$VALUES_FILE" \
        --wait \
        --timeout 10m

    log_info "Prometheus 설치를 완료하였습니다...!"

    log_info "Loki, Fluent-bit, Grafana 배포를 시작합니다..."

    kubectl apply -k "${MONITORING_PATH}" --server-side --force-conflicts

    # Loki
    kubectl wait --for=condition=available deploy/loki-deploy -n monitoring --timeout=180s

    # Grafana
    kubectl wait --for=condition=available deploy/grafana-deploy -n monitoring --timeout=180s

    # Fluent-bit
    kubectl rollout status ds/fluent-bit-daemon -n monitoring --timeout=180s

    log_info "Monitoring 네임스페이스 배포를 모두 완료하였습니다...!"
}

# # Argo Rollouts 설치 및 배포 (Helm)
# deploy_rollouts() {
#     log_info "Argo Rollouts 설치를 시작합니다..."

#     helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
#     helm repo update

#     helm upgrade --install argo-rollouts argo/argo-rollouts \
#         -n argo-rollouts \
#         --create-namespace \
# 	    --set dashboard.enabled=true \
# 	    --set dashboard.service.type=NodePort \
# 	    --set dashboard.service.nodePort=30100 \
#         --wait \
#         --timeout 5m

#     log_info "Argo Rollouts 설치 및 배포를 모두 완료하였습니다...!"
# }

# spot 네임스페이스 배포 (Helm)
deploy_spot() {
    CHART_PATH="${BASE_DIR}/../spot-apps"
    
    log_info "Spot 네임스페이스 배포를 시작합니다..."

    helm upgrade --install spot "${CHART_PATH}" \
        -n spot

    # spot-gateway
    kubectl wait --for=condition=available deploy/spot-gateway -n spot --timeout=180s

    # spot-user
    kubectl wait --for=condition=available deploy/spot-user -n spot --timeout=180s

    # spot-store
    kubectl wait --for=condition=available deploy/spot-store -n spot --timeout=180s

    # spot-order
    kubectl wait --for=condition=available deploy/spot-order -n spot --timeout=180s

    # spot-payment
    kubectl wait --for=condition=available deploy/spot-payment -n spot --timeout=180s

    log_info "Spot 네임스페이스 배포를 모두 완료하였습니다...!"
}

main() {


    local run_monitoring=true

    case "${1:-}" in
        --bootstrap) bootstrap; exit 0 ;;
        --infra) deploy_infra; exit 0 ;;
        --monitoring) deploy_monitoring; exit 0 ;;
        --rollouts) deploy_rollouts; exit 0 ;;
        --spot) deploy_spot; exit 0 ;;
        --no-monitoring) run_monitoring=false ;;
        "")              ;;
        *) log_error "알 수 없는 옵션: $1"; exit 1 ;;
    esac

    log_info "로컬 환경 배포를 시작합니다..."
    bootstrap
    deploy_infra

    if [[ "$run_monitoring" == true ]]; then
        deploy_monitoring
    else
        log_info "Monitoring 네임스페이스 배포를 건너뜁니다..."
    fi
    
    deploy_rollouts
    deploy_spot

    log_info "로컬 환경 배포가 모두 완료되었습니다!"
}

main "$@"
