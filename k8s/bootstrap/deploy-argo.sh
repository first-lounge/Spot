#!/bin/bash
set -euo pipefail

# 1. 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 2. ArgoCD 설치
echo "🛠️  ArgoCD 설치를 시작합니다."

kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ ArgoCD 서버 기동 대기 중..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

if [ -f "$BASE_DIR/../argo/argocd-server-svc.yaml" ]; then
    echo "🌐 ArgoCD Service 배포 중..."
    kubectl apply -f "$BASE_DIR/../argo/argocd-server-svc.yaml"
fi

echo "🎉 ArgoCD의 배포가 완료되었습니다!"

echo "🆔 ArgoCD 아이디 : admin"
echo "🔑 ArgoCD 비밀번호 : $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"