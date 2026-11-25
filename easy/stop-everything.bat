@echo off
cd /d "%~dp0.."
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml -f docker-compose.logging.yml down
docker compose -f docker-compose.jenkins.yml down
echo Stopped. Data kept. (Add -v to delete data.)
pause
