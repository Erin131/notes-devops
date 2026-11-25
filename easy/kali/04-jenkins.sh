#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
sudo sysctl -w vm.max_map_count=262144
docker compose down || true
docker compose -f docker-compose.jenkins.yml up -d --build
echo "Waiting for Jenkins to start..."; sleep 45
echo; echo "JENKINS ADMIN PASSWORD:"
docker compose -f docker-compose.jenkins.yml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
echo; echo "OPEN: http://localhost:8080  and  http://localhost:9000 (admin/admin)"
echo "Then follow Part 3 of the Kali guide to create the pipeline job."
