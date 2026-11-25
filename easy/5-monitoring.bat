@echo off
cd /d "%~dp0.."
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
start http://localhost:3000
start http://localhost:9090
echo Grafana login: admin / admin
pause
