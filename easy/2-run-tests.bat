@echo off
cd /d "%~dp0.."
docker run --rm -v "%cd%":/work -w /work python:3.12-slim sh -c "pip install -q -r app/requirements.txt && pytest --cov=app"
pause
