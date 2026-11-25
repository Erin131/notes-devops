@echo off
cd /d "%~dp0.."
docker compose -f docker-compose.jenkins.yml up -d --build
echo Waiting for Jenkins...
timeout /t 40 >nul
echo Jenkins admin password:
docker compose -f docker-compose.jenkins.yml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
start http://localhost:8080
start http://localhost:9000
pause
