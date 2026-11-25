#!/usr/bin/env bash
# Usage: scripts/gitops-update.sh <image:tag>
# Called by Jenkins: puts the new image on the IDLE colour and scales it up,
# so the new version can be tested before traffic is switched.
set -euo pipefail
IMAGE="${1:?image:tag required}"
cd "$(dirname "$0")/../k8s/app"
ACTIVE=$(grep -E '^\s*version:' 20-service.yaml | awk '{print $2}')
IDLE=$([[ "$ACTIVE" == "blue" ]] && echo green || echo blue)
sed -i "s|^\(\s*image:\).*|\1 $IMAGE|" "10-deployment-$IDLE.yaml"
sed -i "s|^\(\s*replicas:\).*|\1 2|" "10-deployment-$IDLE.yaml"
echo "Active: $ACTIVE | New version deployed to idle colour: $IDLE ($IMAGE)"
