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
ARGO_PATH="$BASE_DIR/../overlays/local/argo"

log_info "로컬 환경의 배포를 시작합니다."

for file in "$ARGO_PATH"/*.yaml;
do
    log_info "$file 파일을 배포합니다"
    kubectl apply -f "$file"
done

log_info "로컬 환경의 배포가 완료되었습니다."