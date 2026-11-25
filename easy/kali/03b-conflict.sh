#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
git checkout -b feature/brand-text
sed -i 's/>Notes App$/>My Notes/' app/templates/base.html
git commit -am "Change brand text"
git checkout main
sed -i 's/>Notes App$/>Notes Pro/' app/templates/base.html
git commit -am "Change brand text differently"
git merge feature/brand-text || true
echo; echo "^^^ CONFLICT shown above."; pause
git checkout --theirs app/templates/base.html
git add . && git commit -m "Resolve merge conflict"
git push
git log --oneline --graph --all | head -15
