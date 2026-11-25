#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
minikube stop 2>/dev/null || true
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
echo; echo "Prometheus: http://localhost:9090 (Status > Targets)"
echo "Grafana:    http://localhost:3000 (admin/admin) > Dashboards > Notes App > Notes App - Docker"
echo "Click around http://localhost:5000 to create traffic."
