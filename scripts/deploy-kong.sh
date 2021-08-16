# "---------------------------------------------------------"
# "-                                                       -"
# "-  Apply the configmap, secret, and deployment  -"
# "-  manifests to the cluster.                            -"
# "-                                                       -"
# "---------------------------------------------------------"

# Bash safeties: exit on error, no unset variables, pipelines can't hide errors
set -euo pipefail

# Directory of this script.
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=scripts/common.sh
source "$ROOT"/scripts/common.sh

# Ensure the bastion SSH tunnel/proxy is up/running
# shellcheck source=scripts/proxy.sh
source "$ROOT"/scripts/proxy.sh

helm repo add kong https://charts.konghq.com
helm repo update

# Set the HTTPS_PROXY env var to allow kubectl to bounce through
# the bastion host over the locally forwarded port 8888.
export HTTPS_PROXY=localhost:8888

K8S_NAMESPACE="kong"

# Create the configmap that includes the connection string for the DB.
echo 'Creating the Configmap'
POSTGRES_PRIVATE_IP="$(cd terraform && terraform output kong_postgres_private_ip)"
kubectl create configmap pgconnection \
  --namespace="${K8S_NAMESPACE}" \
  --from-literal=postgres_private_ip="${POSTGRES_PRIVATE_IP}" \
  --dry-run -o yaml | kubectl apply -f -

# Create the secret that includes the user/pass for pgadmin
echo 'Creating the Console secret'
POSTGRES_USER="$(cd terraform && terraform output kong_postgres_user)"
POSTGRES_PASS="$(cd terraform && terraform output kong_postgres_pass)"
kubectl create secret generic pgsecrets \
  --namespace="${K8S_NAMESPACE}" \
  --from-literal=user="${POSTGRES_USER}" \
  --from-literal=password="${POSTGRES_PASS}" \
  --dry-run -o yaml | kubectl apply -f -

# Install Kong and Konga
HELM_NAMESPACE="${K8S_NAMESPACE}" helm upgrade --install --debug -n "${K8S_NAMESPACE}" \
  kong -f ./helm-charts/kong/values/kong-admin.yaml kong/kong

HELM_NAMESPACE="${K8S_NAMESPACE}" helm upgrade --install --debug -n "${K8S_NAMESPACE}" \
  konga ./helm-charts/konga

# Close ssh proxy to bastion host
source "$ROOT"/scripts/kill-proxy.sh && echo "Killed ssh proxy"