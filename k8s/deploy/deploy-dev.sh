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

# 메인 경로 (레포 루트 = k8s/deploy 에서 두 단계 위)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 클러스터 초기 세팅
bootstrap() {
    KUSTOMIZATION_DIR="$BASE_DIR/k8s/base"

    # 네임스페이스 생성
    log_info "네임스페이스 생성을 시작합니다..."
    for ns in infra monitoring spot; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done

    echo "--------------------------------------"
    log_info "네임스페이스 생성을 완료하였습니다!"
    echo "--------------------------------------"

    log_info "ConfigMap과 secret 생성을 시작합니다..."
    
    kubectl apply -k "$KUSTOMIZATION_DIR"

    echo "--------------------------------------"
    log_info "ConfigMap과 secret 생성을 완료하였습니다."
    echo "--------------------------------------"
}

# infra 네임스페이스 Helm + Kustomize 배포
# 순서 : Kafka NodePool -> Kafka Connect -> Kafka Connector -> Kafka Connect -> Temporal -> 나머지
deploy_infra() {
    INFRA_PATH="${BASE_DIR}/k8s/overlays/dev/infra"

    log_info "Storage Class 생성을 시작합니다..."
    kubectl apply -f "${BASE_DIR}/k8s/overlays/dev/storage-class.yaml"

    log_info "Strimzi Kafka Operator 설치를 시작합니다..."
    
    kubectl create namespace strimzi --dry-run=client -o yaml | kubectl apply -f -

    helm repo add strimzi https://strimzi.io/charts/ >/dev/null 2>&1 || true
    helm repo update
    helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
        -n strimzi \
        --set watchNamespaces={infra} \
        --wait \
        --timeout 10m
    
    log_info "Strimzi Kafka Operator 설치를 완료하였습니다..."

    log_info "Kafka, Temporal, RDS-relay 배포를 시작합니다..."

    kubectl apply -k "${INFRA_PATH}"

    kubectl wait --for=condition=Ready kafka/kafka-cluster -n infra --timeout=300s
    kubectl wait --for=condition=Ready kafkaconnect/spot-connect -n infra --timeout=300s
    kubectl wait --for=condition=available deploy/temporal -n infra --timeout=180s
    kubectl wait --for=condition=available deploy/kafka-ui -n infra --timeout=180s
    kubectl wait --for=condition=available deploy/temporal-ui -n infra --timeout=180s
    kubectl wait --for=condition=available deploy/rds-relay -n infra --timeout=180s

    log_info "Kafka, Temporal, RDS-relay 배포를 완료하였습니다..."
}

# monitoring 네임스페이스 Helm + Kustomize 배포
deploy_monitoring() {
    MONITORING_PATH="${BASE_DIR}/k8s/overlays/dev/monitoring"
    VALUES_FILE="${MONITORING_PATH}/platform/prometheus/values.yaml"
    
    log_info "Storage Class 매니페스트 생성을 시작합니다..."
    
    kubectl apply -f "${BASE_DIR}/k8s/overlays/dev/storage-class.yaml"
    
    log_info "생성을 완료하였습니다..."

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

    log_info "Prometheus 설치를 완료하였습니다..."

    log_info "Loki, Fluent-bit, Grafana 배포를 시작합니다..."

    kubectl apply -k "${MONITORING_PATH}"

    kubectl wait --for=condition=available deploy/loki-deploy -n monitoring --timeout=180s
    kubectl wait --for=condition=available deploy/grafana-deploy -n monitoring --timeout=180s
    kubectl rollout status ds/fluent-bit-daemon -n monitoring --timeout=180s

    log_info "monitoring 네임스페이스 배포를 모두 완료하였습니다..."
}

# spot 네임스페이스 Helm 배포
deploy_apps() {
    # 경로 변수
    TERRAFORM_PATH="${BASE_DIR}/terraform/environments/dev"
    CHART_PATH="${BASE_DIR}/k8s/spot-apps"
    
    # Terraform 폴더로 이동
    cd "${TERRAFORM_PATH}"

    # Terraform Outputs
    BUCKET_NAME=$(terraform output -raw bucket_name)
    ACM_ARN=$(terraform output -raw acm_certificate_arn)
    WAF_ARN=$(terraform output -raw waf_acl_arn)
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com"

    log_info "spot 네임스페이스 배포를 시작합니다..."

    helm upgrade --install spot "${CHART_PATH}" \
        -n spot \
        -f "${BASE_DIR}/k8s/overlays/dev/apps/values-dev.yaml" \
        --set "ingress.annotations.alb\.ingress\.kubernetes\.io/certificate-arn=${ACM_ARN}" \
        --set "ingress.annotations.alb\.ingress\.kubernetes\.io/wafv2-acl-arn=${WAF_ARN}" \
        --set "ingress.bucket=${BUCKET_NAME}" \
        --set "global.repository=${ECR_REGISTRY}"

    kubectl wait --for=condition=available deploy/spot-gateway -n spot --timeout=180s
    kubectl wait --for=condition=available deploy/spot-user -n spot --timeout=180s
    kubectl wait --for=condition=available deploy/spot-store -n spot --timeout=180s
    kubectl wait --for=condition=available deploy/spot-order -n spot --timeout=180s
    kubectl wait --for=condition=available deploy/spot-payment -n spot --timeout=180s
}

main() {
    bootstrap
    deploy_infra
    # deploy_monitoring
    deploy_apps
}

main "$@"