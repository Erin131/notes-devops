@echo off
cd /d "%~dp0.."
docker compose -f docker-compose.yml -f docker-compose.logging.yml up -d --build
echo Wait 1-2 minutes for Kibana, then open http://localhost:5601
echo Create data view: notes-logs-*
pause
