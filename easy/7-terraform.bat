@echo off
cd /d "%~dp0.."
docker compose build
cd terraform
if not exist terraform.tfvars copy terraform.tfvars.example terraform.tfvars
echo Edit terraform/terraform.tfvars (set docker_host for Windows) then press a key
pause
terraform init
terraform apply -auto-approve
pause
