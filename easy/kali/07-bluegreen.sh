#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
COLOR="${1:-green}"
./scripts/switch-bluegreen.sh "$COLOR"
kubectl apply -f k8s/app
sleep 10; kubectl get pods -n notes
echo "Refresh the app: navbar colour/badge = $COLOR"
echo "Switch back with: ./easy/kali/07-bluegreen.sh blue   then: git checkout -- k8s/app"
