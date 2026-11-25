#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
read -r -p "GitHub username: " GHUSER
read -r -p "Your name: " NAME
read -r -p "Your email: " EMAIL
echo "Create an EMPTY PUBLIC repo named notes-devops on github.com first."
echo "When Git asks for a password, paste your Personal Access Token (not your GitHub password)."
read -r -p "Press Enter when the repo exists..." _
git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global credential.helper store
[ -d .git ] || git init -b main
git add . && git commit -m "Initial commit: notes app" || true
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$GHUSER/notes-devops.git"
git push -u origin main
echo "Done. Next: ./easy/kali/03b-conflict.sh"
