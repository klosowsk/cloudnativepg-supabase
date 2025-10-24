#!/bin/bash
set -e

echo "Installing Zalando Postgres Operator..."

# Add Helm repository
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo update

# Install operator
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  --values values.yaml

echo ""
echo "✅ Postgres Operator installed successfully!"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n postgres-operator"
echo ""
echo "Check operator logs:"
echo "  kubectl logs -n postgres-operator deployment/postgres-operator"
echo ""
echo "Next: Install Supabase HA with:"
echo "  helm install supabase-prod ../../helm-charts/supabase-ha \\"
echo "    --namespace prod-supabase \\"
echo "    --create-namespace \\"
echo "    --values ../production/values.yaml"
