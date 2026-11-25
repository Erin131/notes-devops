#!/usr/bin/env bash
# Usage: scripts/switch-bluegreen.sh blue|green
# Points the Service at the chosen colour, scales it to 2 pods, scales the other to 0.
set -euo pipefail
NEW="${1:-}"
[[ "$NEW" == "blue" || "$NEW" == "green" ]] || { echo "Usage: $0 blue|green"; exit 1; }
OLD=$([[ "$NEW" == "blue" ]] && echo green || echo blue)
cd "$(dirname "$0")/../k8s/app"
sed -i "s|^\(\s*version:\).*|\1 $NEW|" 20-service.yaml
sed -i "s|^\(\s*replicas:\).*|\1 2|" "10-deployment-$NEW.yaml"
sed -i "s|^\(\s*replicas:\).*|\1 0|" "10-deployment-$OLD.yaml"
echo "Traffic now goes to: $NEW"
echo "Next: kubectl apply -f k8s/app   (or git commit + push and let ArgoCD sync)"
