#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
LOG_FILE="./provisioning.log"
TOKEN_FILE="./token_file"
SERVICE_ACCOUNT_NAME="cloudguard-controller"
DEFAULT_NAMESPACE="default"
DRY_RUN=false
INSTALL_MODE=false

log_info()    { echo -e "\033[1;34m[INFO]\033[0m    $*" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m   $*" | tee -a "$LOG_FILE" >&2; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*" | tee -a "$LOG_FILE"; }

run_cmd() {
  if $DRY_RUN; then
    echo -e "\033[1;33m[DRY-RUN]\033[0m Would run: $*" | tee -a "$LOG_FILE"
  else
    eval "$@" | tee -a "$LOG_FILE"
  fi
}

print_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --help                         Show this help message and exit
  --install                      Install CloudGuard objects on the cluster
  --uninstall                    Remove all created Kubernetes objects
  --create-datacenter-object     Register the cluster in SmartConsole using the API
  --dry-run                      Simulate actions without applying changes
  --status                       Check if the 'cloudguard-controller-secret' exists and show details

This script provisions a Kubernetes cluster for integration with Check Point CloudGuard.
EOF
  exit 0
}

uninstall_resources() {
  log_info "Removing Kubernetes objects..."
  run_cmd kubectl delete serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$DEFAULT_NAMESPACE" --ignore-not-found=true
  run_cmd kubectl delete clusterrole endpoint-reader --ignore-not-found=true
  run_cmd kubectl delete clusterrolebinding allow-cloudguard-access-endpoints --ignore-not-found=true
  run_cmd kubectl delete clusterrole pod-reader --ignore-not-found=true
  run_cmd kubectl delete clusterrolebinding allow-cloudguard-access-pods --ignore-not-found=true
  run_cmd kubectl delete clusterrole service-reader --ignore-not-found=true
  run_cmd kubectl delete clusterrolebinding allow-cloudguard-access-services --ignore-not-found=true
  run_cmd kubectl delete clusterrole node-reader --ignore-not-found=true
  run_cmd kubectl delete clusterrolebinding allow-cloudguard-access-nodes --ignore-not-found=true
  run_cmd "rm -f \"$TOKEN_FILE\""
  log_success "Uninstallation completed."
  exit 0
}

check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log_error "kubectl is not installed."
    read -rp "Install kubectl now? [y/N]: " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      rm kubectl
      log_success "kubectl installed."
      echo "Exiting. Please configure a Kubernetes cluster and rerun the script."
      exit 0
    else
      echo "Exiting. kubectl is required."
      exit 1
    fi
  fi

  if [[ -f "$KUBECONFIG" || -f "$HOME/.kube/config" || -d "$HOME/.kube" ]]; then
    log_info "Kubeconfig detected. Continuing..."
  else
    log_error "No usable kubeconfig found. Run kubectl cluster-info to test. Configure a Kubernetes cluster and rerun the script."
    exit 1
  fi

  if ! kubectl config get-contexts &>/dev/null; then
    log_error "kubectl is not configured properly. No contexts available."
    exit 1
  fi
}

select_kube_context() {
  local current_context
  current_context=$(kubectl config current-context)
  echo "Current kubectl context: $current_context"
  read -rp "Proceed with this context for CloudGuard provisioning? [y/N]: " proceed

  if [[ "$proceed" =~ ^[Yy]$ ]]; then
    log_success "Using context: $current_context"
    return
  fi

  echo "Available contexts:"
  kubectl config get-contexts --no-headers | awk '{print $1}'
  read -rp "Enter the context to use (or press Enter to use current): " selected_context
  selected_context="${selected_context:-$current_context}"

  if ! kubectl config use-context "$selected_context" &>/dev/null; then
    log_error "Failed to switch to context: $selected_context"
    exit 1
  fi

  log_success "Switched to context: $selected_context"
}

provision_cloudguard() {
  log_info "Creating CloudGuard service account and RBAC objects..."
  run_cmd kubectl create serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$DEFAULT_NAMESPACE"
  run_cmd kubectl create clusterrole endpoint-reader --verb=get,list --resource=endpoints
  run_cmd kubectl create clusterrolebinding allow-cloudguard-access-endpoints --clusterrole=endpoint-reader --serviceaccount=$DEFAULT_NAMESPACE:$SERVICE_ACCOUNT_NAME
  run_cmd kubectl create clusterrole pod-reader --verb=get,list --resource=pods
  run_cmd kubectl create clusterrolebinding allow-cloudguard-access-pods --clusterrole=pod-reader --serviceaccount=$DEFAULT_NAMESPACE:$SERVICE_ACCOUNT_NAME
  run_cmd kubectl create clusterrole service-reader --verb=get,list --resource=services
  run_cmd kubectl create clusterrolebinding allow-cloudguard-access-services --clusterrole=service-reader --serviceaccount=$DEFAULT_NAMESPACE:$SERVICE_ACCOUNT_NAME
  run_cmd kubectl create clusterrole node-reader --verb=get,list --resource=nodes
  run_cmd kubectl create clusterrolebinding allow-cloudguard-access-nodes --clusterrole=node-reader --serviceaccount=$DEFAULT_NAMESPACE:$SERVICE_ACCOUNT_NAME

  log_info "Creating service account secret..."
  if ! $DRY_RUN; then
    kubectl apply -n "$DEFAULT_NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudguard-controller-secret
  annotations:
    kubernetes.io/service-account.name: $SERVICE_ACCOUNT_NAME
type: kubernetes.io/service-account-token
EOF
    kubectl create token "$SERVICE_ACCOUNT_NAME" -n "$DEFAULT_NAMESPACE" > "$TOKEN_FILE"
    log_success "Token saved to $TOKEN_FILE"
  else
    echo -e "\033[1;33m[DRY-RUN]\033[0m Would apply service account secret and generate token" | tee -a "$LOG_FILE"
  fi
}

authenticate_to_smartconsole() {
  log_info "Authenticating to SmartConsole API..."
  local login
  login=$(curl -sk -X POST "https://${SMARTCENTER_HOST}/web_api/login" \
    -H "Content-Type: application/json" \
    -d "{\"user\":\"${SMARTCENTER_USER}\",\"password\":\"${SMARTCENTER_PASS}\"}")
  if ! echo "$login" | jq -e '.sid' &>/dev/null; then
    log_error "SmartConsole login failed or invalid JSON response."
    echo "$login" >> "$LOG_FILE"
    exit 1
  fi
  SID=$(echo "$login" | jq -r '.sid')
  log_success "Authenticated with SID: $SID"
}

create_datacenter_object_via_api() {
  authenticate_to_smartconsole
  if [[ ! -s "$TOKEN_FILE" ]]; then
    log_error "Token file is empty or missing."
    exit 1
  fi
  local server_url
  server_url=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  log_info "Creating DataCenter object in SmartConsole..."
  run_cmd curl -sk -X POST "https://${SMARTCENTER_HOST}/web_api/add-data-center-object" \
    -H "Content-Type: application/json" -H "X-chkp-sid: $SID" \
    -d "{
      \"name\": \"CloudGuard-K8s\",
      \"type\": \"kubernetes\",
      \"server\": \"${server_url}\",
      \"token\": \"$(< \"$TOKEN_FILE\")\",
      \"comments\": \"Provisioned by automation script\"
    }"
  run_cmd curl -sk -X POST "https://${SMARTCENTER_HOST}/web_api/publish" -H "Content-Type: application/json" -H "X-chkp-sid: $SID" -d '{}'
  run_cmd curl -sk -X POST "https://${SMARTCENTER_HOST}/web_api/logout" -H "X-chkp-sid: $SID"
  log_success "SmartConsole object published and session closed."
}

check_secret_status() {
  log_info "Checking status of Kubernetes secret for CloudGuard..."

  if kubectl get secret cloudguard-controller-secret -n "$DEFAULT_NAMESPACE" &>/dev/null; then
    log_success "Secret 'cloudguard-controller-secret' exists in namespace '$DEFAULT_NAMESPACE'."
    kubectl describe secret cloudguard-controller-secret -n "$DEFAULT_NAMESPACE" | tee -a "$LOG_FILE"
  else
    log_error "Secret 'cloudguard-controller-secret' not found in namespace '$DEFAULT_NAMESPACE'."
    exit 1
  fi
}

main() {
  if [[ $# -eq 0 ]]; then
    print_help
  fi

  for arg in "$@"; do
    case "$arg" in
      --dry-run)
        DRY_RUN=true
        INSTALL_MODE=true
        log_info "Dry-run mode activated. No changes will be applied."
        ;;
      --install)
        INSTALL_MODE=true
        ;;
    esac
  done

  case "${1:-}" in
    --help)
      print_help
      ;;
    --uninstall)
      uninstall_resources
      ;;
    --create-datacenter-object)
      if [[ -z "${SMARTCENTER_USER:-}" || -z "${SMARTCENTER_PASS:-}" || -z "${SMARTCENTER_HOST:-}" ]]; then
        echo
        log_error "Missing one or more required environment variables:"
        [[ -z "${SMARTCENTER_USER:-}" ]] && echo "  - SMARTCENTER_USER"
        [[ -z "${SMARTCENTER_PASS:-}" ]] && echo "  - SMARTCENTER_PASS"
        [[ -z "${SMARTCENTER_HOST:-}" ]] && echo "  - SMARTCENTER_HOST"
        echo
        echo "Please set them and rerun:"
        echo "  export SMARTCENTER_USER=admin"
        echo "  export SMARTCENTER_PASS=secret"
        echo "  export SMARTCENTER_HOST=192.168.1.10"
        echo
        exit 1
      fi
      create_datacenter_object_via_api
      exit 0
      ;;
    --status)
      check_kubectl
      check_secret_status
      exit 0
      ;;
  esac

  if $INSTALL_MODE; then
    check_kubectl
    select_kube_context
    provision_cloudguard

    current_context=$(kubectl config current-context)
    cluster_info=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.cluster}")
    cluster_server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$cluster_info\")].cluster.server}")

    echo
    echo "📎 Token file saved at: $TOKEN_FILE displayed below"
    echo "================ start of token_file ================"
    echo
    if [[ -f "$TOKEN_FILE" ]]; then
      cat "$TOKEN_FILE" | tee -a "$LOG_FILE"
    else
      echo -e "\033[1;33m[WARNING]\033[0m token_file not found." | tee -a "$LOG_FILE"
      echo "If this was a --dry-run, you can likely ignore this message." | tee -a "$LOG_FILE"
    fi
    echo
    echo "================ end of token_file =================="
    echo ""

    echo "🧭 Using kubectl context: $current_context"
    echo "🌐 Kubernetes API server: $cluster_server"
    echo ""
    echo "===== ip addresses associated to host ====="
    run_cmd ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1
    echo "==========================================="
    echo
    echo "🔑 Use the token and server above in SmartConsole:"
    echo "    SmartConsole → Objects → Cloud → Datacenters → Kubernetes"
    echo

    if $DRY_RUN; then
      log_info "Dry-run complete. No changes were applied."
      echo "Review the log file for all simulated actions: $LOG_FILE"
    fi
  else
    log_info "No valid operation was selected. Use --install, --uninstall, or --create-datacenter-object."
    print_help
  fi
}

main "$@"

