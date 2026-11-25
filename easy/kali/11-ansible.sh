#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
sudo apt install -y ansible
cd ansible
ansible-playbook playbooks/02-install-kubernetes.yml --ask-become-pass
ansible-playbook playbooks/03-deploy-app.yml
ansible-playbook playbooks/04-configure.yml --ask-become-pass
echo "Running 04 again to show idempotency (changed=0):"
ansible-playbook playbooks/04-configure.yml --ask-become-pass
