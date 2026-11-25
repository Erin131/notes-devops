@echo off
cd /d "%~dp0.."
docker compose up -d --build
start http://localhost:5000
echo App is running at http://localhost:5000
pause
