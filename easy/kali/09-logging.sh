#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down 2>/dev/null || true
sudo sysctl -w vm.max_map_count=262144
docker compose -f docker-compose.yml -f docker-compose.logging.yml up -d --build
echo "Wait 2 minutes, then open http://localhost:5601"
echo "Stack Management > Data Views > Create: notes-logs-*  (timestamp field @timestamp) > Discover"
