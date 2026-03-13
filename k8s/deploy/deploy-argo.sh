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
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZATION_DIR="$BASE_DIR/../base"
ARGO_SVC_FILE="$BASE_DIR/../overlays/dev/argo/argocd-server-svc.yaml"

# 2. 네임스페이스 및 configMap 생성
log_info "네임스페이스와 ConfigMap 생성을 시작합니다..."
kubectl apply -k "$KUSTOMIZATION_DIR"
log_info "네임스페이스와 ConfigMap 생성을 완료하였습니다."

# 3. ArgoCD 설치 및 배포
log_info "ArgoCD 설치 및 배포를 시작합니다..."

kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "ArgoCD 서버 기동 대기 중..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

if [ -f "$ARGO_SVC_FILE" ]; then
    log_info "ArgoCD Service 배포 중..."
    kubectl apply -f "$ARGO_SVC_FILE"
else
    log_error "ArgoCD Service 매니페스트가 없습니다. 파일 경로를 확인해주세요: $ARGO_SVC_FILE"
    exit 1
fi

echo "=================================================="
echo "🆔 ArgoCD 아이디 : admin"
echo "🔑 ArgoCD 비밀번호 : $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "=================================================="

log_info "ArgoCD의 설치 및 배포가 완료되었습니다!"