#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
docker compose down 2>/dev/null || true
if ! command -v terraform >/dev/null; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com bookworm main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install -y terraform
fi
docker compose build
cd terraform
if [ ! -f terraform.tfvars ]; then
  printf 'db_password = "tf-demo-password"\nsecret_key  = "tf-demo-secret-key-change-me-0123456789"\n' > terraform.tfvars
fi
terraform init
terraform plan
terraform apply -auto-approve
echo "OPEN the app_url above (http://localhost:5001)"; pause
terraform destroy -auto-approve
terraform apply -auto-approve
echo "Destroyed and re-created = reproducible."
