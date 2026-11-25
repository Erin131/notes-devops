#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
python3 -m venv .venv
. .venv/bin/activate
pip install -q -r app/requirements.txt
pytest --cov=app
deactivate
echo "You should see: 12 passed"
