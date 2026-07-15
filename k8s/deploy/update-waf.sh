#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Terraform 결과 가져오기
echo "🔍 Terraform에서 WAF ARN을 가져오는 중..."
WAF_ARN="$(cd "$BASE_DIR/terraform/environments/dev" && terraform output -raw waf_acl_arn)"

if ! echo "$WAF_ARN" | grep -Eq "^arn:aws:wafv2"; then
    echo "❌ 실패: 값이 일치하지 않거나 비어 있습니다."
    exit 1
fi

echo "✅ 성공: $WAF_ARN"

# values 파일 수정
cd "$BASE_DIR/k8s/spot-apps"
echo "📝 values-dev.yaml 파일을 수정하는 중..."

WAF_ARN=$WAF_ARN yq -i '.ingress.annotations."alb.ingress.kubernetes.io/wafv2-acl-arn" = env(WAF_ARN)' values-dev.yaml
echo "✅ 성공: 아래 파일이 수정되었습니다. 커밋·PR을 진행해주세요."
echo "$(git --no-pager diff -- values-dev.yaml)"