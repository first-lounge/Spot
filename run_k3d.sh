#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="spot-cluster"
REGISTRY_NAME="spot-registry.localhost"
REGISTRY_PORT="5111"

# 로컬 레지스트리는 프록시 우회
export NO_PROXY="${NO_PROXY:-},localhost,127.0.0.1,spot-registry.localhost,*.localhost"
export no_proxy="${no_proxy:-},localhost,127.0.0.1,spot-registry.localhost,*.localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v k3d &> /dev/null; then
        log_warn "k3d is not installed. Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi

    if ! command -v kustomize &> /dev/null; then
        log_warn "kustomize is not installed. Installing kustomize..."
        brew install kustomize
    fi

    if ! command -v helm &> /dev/null; then
        log_warn "helm is not installed. Installing helm..."
        brew install helm
    fi

    log_info "All prerequisites are met."
}

cleanup_existing() {
    log_info "Cleaning up existing resources..."

    if [ -f "$SCRIPT_DIR/docker-compose.yaml" ]; then
        docker compose -f "$SCRIPT_DIR/docker-compose.yaml" down --remove-orphans 2>/dev/null || true
    fi
    
    log_info "Starting essential infrastructure (DB, Redis) via Docker Compose..."
    docker compose -f "$SCRIPT_DIR/docker-compose.yaml" up -d db redis

    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        log_info "Deleting existing k3d cluster: $CLUSTER_NAME"
        k3d cluster delete "$CLUSTER_NAME"
    fi

    if docker ps -a | grep -q "k3d-$REGISTRY_NAME"; then
        log_info "Removing existing registry..."
        docker rm -f "k3d-$REGISTRY_NAME" 2>/dev/null || true
    fi
}

create_cluster() {
    log_info "Creating k3d cluster with config..."
    k3d cluster create --config "$SCRIPT_DIR/infra/k3d/cluster-config.yaml"

    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=ready node --all --timeout=180s

    log_info "Cluster created successfully!"
}

build_and_push_images() {
    log_info "Building and pushing Docker images to local registry..."

    SERVICES=("spot-gateway" "spot-user" "spot-store" "spot-order" "spot-payment")
  
    log_info "Building Kafka Connect with Debezium..."
    docker build -t "$REGISTRY_NAME:$REGISTRY_PORT/spot-connect-custom:latest" "$SCRIPT_DIR/infra/k8s/base/kafka/"
    n=0
    until [ $n -ge 3 ]; do
        docker push "$REGISTRY_NAME:$REGISTRY_PORT/spot-connect-custom:latest" && break
        n=$((n+1))
        log_warn "Push failed for spot-connect-custom. Retrying ($n/3)..."
        sleep 2
    done
    
    for service in "${SERVICES[@]}"; do
        log_info "Building $service..."
        (cd "$SCRIPT_DIR/$service" && ./gradlew bootJar -x test)
        
        docker build -t "$REGISTRY_NAME:$REGISTRY_PORT/$service:latest" "$SCRIPT_DIR/$service"

        n=0
        until [ $n -ge 3 ]; do
            docker push "$REGISTRY_NAME:$REGISTRY_PORT/$service:latest" && break
            n=$((n+1))
            log_warn "Push failed for $service. Retrying ($n/3)..."
            sleep 2
        done
        log_info "$service image pushed successfully!"
    done
  }

install_argocd() {
    log_info "Installing ArgoCD..."

    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

    if [ -f "$SCRIPT_DIR/infra/argo/argocd-ingress.yaml" ]; then
        kubectl apply -f "$SCRIPT_DIR/infra/argo/argocd-ingress.yaml"
    fi

    log_info "ArgoCD installed successfully!"
}

install_prometheus() {
    log_info "Installing Prometheus (kube-prometheus-stack) via Helm..."

    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update

    VALUES_FILE="$SCRIPT_DIR/infra/k8s/base/monitoring/prometheus/value.yaml"
    if [ ! -f "$VALUES_FILE" ]; then
        log_error "Prometheus values file not found: $VALUES_FILE"
        exit 1
    fi

    helm upgrade --install prom prometheus-community/kube-prometheus-stack \
        -n monitoring \
        -f "$VALUES_FILE" \
        --wait \
        --timeout 10m

    log_info "Prometheus installed successfully!"
}

install_strimzi() {
  log_info "Installing Strimzi Kafka Operator via Helm..."
  
  kubectl create namespace strimzi --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace spot --dry-run=client -o yaml | kubectl apply -f -
  
  helm repo add strimzi https://strimzi.io/charts/ >/dev/null 2>&1 || true
  helm repo update

  helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
    -n strimzi \
    --set watchNamespaces={spot} \
    --wait
  
  log_info "Strimzi Operator installed successfully!"
}

deploy_all() {
    log_info "Deploying all resources using Kustomize..."

    # Ingress Controller 설치
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.3/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --for=condition=ready pod -n ingress-nginx --selector=app.kubernetes.io/component=controller --timeout=120s

    # Kustomize 배포
    kustomize build "$SCRIPT_DIR/infra/k8s/" --load-restrictor LoadRestrictionsNone | kubectl apply -f -

#    log_info "Waiting for infrastructure to be ready..."
#    kubectl wait --for=condition=available deployment/postgres -n spot --timeout=180s
#    kubectl wait --for=condition=available deployment/redis -n spot --timeout=180s
    
    log_info "Waiting for Kafka Cluster (KRaft)..."
    kubectl wait --for=condition=Ready kafka/spot-cluster -n spot --timeout=300s

    log_info "Waiting for Kafka Connect..."
    kubectl wait --for=condition=Ready kafkaconnect/spot-connect -n spot --timeout=300s

    log_info "Waiting for Kafka UI..."
    kubectl wait --for=condition=available deployment/kafka-ui -n spot --timeout=180s
  
    log_info "Waiting for Temporal..."
    kubectl wait --for=condition=available deployment/temporal -n spot --timeout=180s
    kubectl wait --for=condition=available deployment/temporal-ui -n spot --timeout=180s

    log_info "Infrastructure deployed successfully!"

    log_info "Waiting for monitoring system to be ready..."
    kubectl wait --for=condition=available deployment/loki-deploy -n monitoring --timeout=180s || true
    kubectl wait --for=condition=available deployment/grafana-deploy -n monitoring --timeout=180s || true
    kubectl rollout status daemonset/fluent-bit-daemon -n monitoring --timeout=180s || true

    log_info "Monitoring System deployed successfully!"
}

restart_grafana_for_provisioning() {
    log_info "Restarting Grafana to apply provisioning..."
    kubectl -n monitoring rollout restart deployment/grafana-deploy || true
    kubectl -n monitoring rollout status deployment/grafana-deploy --timeout=180s || true
}

show_status() {
    log_info "=== Cluster Status ==="
    kubectl get nodes
    kubectl get pods -n spot
    kubectl get pods -n monitoring

    echo ""
    echo "Access points:"
    echo "  - ArgoCD UI:   http://localhost:30090"
    echo "  - Gateway API: http://spot.localhost"
    echo "  - Grafana UI:  http://grafana.localhost"
    echo ""
    echo "ArgoCD credentials:"
    echo "  - Username: admin"
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Not available yet")
    echo "  - Password: $ARGOCD_PASSWORD"
    echo ""
    echo "Useful commands:"
    echo "  - kubectl get pods -n spot          # Check application pods"
    echo "  - kubectl logs -f <pod> -n spot     # View pod logs"
    echo "  - k3d cluster stop $CLUSTER_NAME    # Stop cluster"
    echo "  - k3d cluster delete $CLUSTER_NAME  # Delete cluster"
    echo "=============================================="
}

main() {
    case "${1:-}" in
        --clean)
            cleanup_existing
            exit 0
            ;;
        --build_only)
            build_and_push_images
            exit 0
            ;;
        --deploy-only)
            deploy_all
            exit 0
            ;;
    esac

    check_prerequisites
    cleanup_existing
    create_cluster
    build_and_push_images
    install_argocd
    install_prometheus
    install_strimzi
    deploy_all
    restart_grafana_for_provisioning
    show_status
}

main "$@"
