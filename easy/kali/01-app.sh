#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
docker compose up -d --build
sleep 5
docker ps
echo; echo "OPEN: http://localhost:5000  (register, add notes)"
echo "Then run: ./easy/kali/02-tests.sh"
