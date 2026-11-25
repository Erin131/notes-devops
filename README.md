# Notes App - End-to-End DevOps Pipeline (ENSP461 Capstone)

A small Flask + PostgreSQL notes app, wrapped in a complete DevOps pipeline:
Git → Jenkins → Docker → Kubernetes → Ansible → Terraform → Prometheus/Grafana → EFK logging → SonarQube/Trivy security → Blue-Green → ArgoCD (GitOps).

```
app/            Flask source code + tests          k8s/app/       Kubernetes manifests (ArgoCD watches this)
Dockerfile      Container image                    k8s/monitoring Prometheus + Grafana on Kubernetes
docker-compose*.yml   Compose stacks               k8s/logging    Fluentd + Elasticsearch + Kibana on Kubernetes
Jenkinsfile     CI/CD pipeline                     k8s/extras     Ingress + autoscaler (bonus)
jenkins/        Jenkins image (Docker, Sonar...)   argocd/        GitOps Application
ansible/        Playbooks                          scripts/       Blue-green + GitOps helper scripts
terraform/      Infrastructure as code             docs/          Architecture, report outline
monitoring/ fluentd/   Config files for compose stacks
```

## 0. What you need on your PC

| Tool | Why | Notes |
|---|---|---|
| Docker Desktop (WSL2 backend on Windows) | Everything runs in containers | 8 GB RAM minimum, 16 GB comfortable |
| Git + GitHub account | Phase 1, GitOps | Use **Git Bash** on Windows to run `.sh` scripts |
| Python 3.12 (optional) | Run the app/tests without Docker | |
| minikube + kubectl | Kubernetes | `winget install Kubernetes.minikube Kubernetes.kubectl` |
| Terraform | Phase 6 | `winget install Hashicorp.Terraform` |
| WSL2 Ubuntu (or any Linux) | Ansible only | Ansible does not run natively on Windows |

**Tip:** your PC can't run everything at once. Do one phase, take screenshots for the report, stop it (`docker compose down`), then move on.

---

## 1. Run the app (2 minutes)

```bash
docker compose up -d --build
```
Open http://localhost:5000 → Register → Login → add notes. Stop with `docker compose down` (add `-v` to wipe the database).

Run the tests without Docker (optional):
```bash
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r app/requirements.txt
pytest --cov=app
```

**REST API** (token based):
```bash
curl -X POST localhost:5000/api/register -H "Content-Type: application/json" -d '{"username":"erin","password":"password123"}'
curl -X POST localhost:5000/api/login    -H "Content-Type: application/json" -d '{"username":"erin","password":"password123"}'
# copy the token, then:
curl localhost:5000/api/notes -H "Authorization: Bearer <TOKEN>"
curl -X POST localhost:5000/api/notes -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"title":"Hi","content":"from the API"}'
```
Other endpoints: `GET/PUT/DELETE /api/notes/<id>`, `/healthz`, `/ready`, `/metrics`.

## 2. Phase 1 - Git & GitHub

```bash
git init -b main && git add . && git commit -m "Initial commit: notes app"
# create an empty repo named notes-devops on GitHub, then:
git remote add origin https://github.com/<you>/notes-devops.git
git push -u origin main
```
Demonstrate branches, merge and a conflict (rubric item):
```bash
git checkout -b feature/title-text      # edit app/templates/base.html (change brand text), commit
git checkout main                        # edit the SAME line differently, commit
git merge feature/title-text             # CONFLICT -> fix the file, then:
git add . && git commit -m "Resolve merge conflict"
git log --oneline --graph --all          # screenshot this
```

## 3. Phase 3 - Docker
Already done in step 1: `Dockerfile` (non-root, healthcheck) and `docker-compose.yml`. Check: `docker ps`, `docker images`.

## 4. Phase 2 - Jenkins CI (+ SonarQube)

```bash
docker compose -f docker-compose.jenkins.yml up -d --build
docker compose -f docker-compose.jenkins.yml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
1. Open http://localhost:8080, paste the password, **Install suggested plugins**, create your admin user.
2. **New Item → Pipeline** (name `notes-app`) → *Pipeline script from SCM* → Git → your GitHub repo URL → branch `main`, script path `Jenkinsfile`.
3. **Build Now.** It runs: checkout → tests → docker build → Trivy scan → package (.tar.gz artifact).
4. **Auto-run on push:** Jenkins polls Git every 2 minutes already (`pollSCM`). For instant GitHub webhooks, expose Jenkins with ngrok (`ngrok http 8080`) and add `https://<ngrok-url>/github-webhook/` under GitHub → Settings → Webhooks.

**SonarQube (Phase 9):** open http://localhost:9000 (login `admin`/`admin`, change password) → *My Account → Security → Generate token*. In Jenkins: *Manage Jenkins → Credentials → Global → Add* → kind **Secret text**, ID `sonar-token`. Then *Build with Parameters* → tick `RUN_SONAR`.

**Docker Hub push:** add credential kind *Username with password*, ID `dockerhub-creds`. *Build with Parameters* → tick `PUSH_IMAGE`, set `DOCKERHUB_USER`.

**Full GitOps loop:** add credential `github-creds` (GitHub username + a Personal Access Token with `repo` scope), tick `UPDATE_GITOPS`. Jenkins then commits the new image tag to `k8s/app` and ArgoCD deploys it.

## 5. Phase 4 - Kubernetes (minikube)

```bash
minikube start --memory 4096 --cpus 2
docker compose build                       # makes the image notes-app:1.0
minikube image load notes-app:1.0          # copy the image into the cluster
kubectl apply -f k8s/app
kubectl get pods -n notes -w
minikube service notes-app -n notes --url  # open the printed URL
```
This creates: Deployment, Service, ConfigMap, Secret, PersistentVolume + PVC, RBAC.

**Scaling**
```bash
kubectl scale deployment notes-app-blue -n notes --replicas=4
kubectl get pods -n notes
```
**Rolling update** (build a changed image, e.g. edit a template, then `docker build -t notes-app:2.0 .` and `minikube image load notes-app:2.0`):
```bash
kubectl set image deployment/notes-app-blue notes-app=notes-app:2.0 -n notes
kubectl rollout status deployment/notes-app-blue -n notes
```
**Rollback**
```bash
kubectl rollout history deployment/notes-app-blue -n notes
kubectl rollout undo deployment/notes-app-blue -n notes
```
Bonus: `kubectl apply -f k8s/extras/hpa.yaml` (after `minikube addons enable metrics-server`) and `k8s/extras/ingress.yaml` (after `minikube addons enable ingress`).

## 6. Phase 5 - Ansible (run inside WSL2 Ubuntu or Linux)

```bash
sudo apt install -y ansible
cd ansible
ansible-playbook playbooks/01-install-docker.yml  --ask-become-pass
ansible-playbook playbooks/02-install-kubernetes.yml --ask-become-pass
ansible-playbook playbooks/03-deploy-app.yml                 # add -e deploy_k8s=true for Kubernetes too
ansible-playbook playbooks/04-configure.yml --ask-become-pass
```
They target `localhost` (see `inventory.ini`). Point the inventory at a remote Ubuntu server to configure that instead. If Docker is already installed you can still run them - Ansible is idempotent (re-running changes nothing).

## 7. Phase 6 - Terraform
```bash
docker compose build                       # the image must exist locally
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit passwords (on Windows also set docker_host)
terraform init
terraform plan
terraform apply                            # builds network + volume + DB + app; open the app_url output
terraform destroy                          # remove everything; apply again = identical result (reproducible)
```
Uses a reusable **module** (`modules/notes_stack`), **variables** and **outputs**. It runs on port 5001 so it doesn't clash with the compose stack.

## 8. Phase 7 - Monitoring (Prometheus + Grafana)

**Docker Compose version**
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
```
- Prometheus http://localhost:9090 → *Status → Targets* (all should be UP)
- Grafana http://localhost:3000 (`admin`/`admin`) → Dashboards → *Notes App - Docker*: request rate, latency, CPU, memory, container health, notes created.
- Generate some traffic (click around the app) so graphs fill in.
- If the *container* panels are empty on Docker Desktop, that's a cAdvisor limitation there - the app panels still work and the Kubernetes version below shows container metrics.

**Kubernetes version**
```bash
kubectl apply -f k8s/monitoring/prometheus.yaml
kubectl create configmap grafana-dashboards -n monitoring --from-file=monitoring/grafana/dashboards/notes-k8s.json
kubectl apply -f k8s/monitoring/grafana.yaml
minikube service grafana -n monitoring --url
```

## 9. Phase 8 - Centralised logging (Fluentd → Elasticsearch → Kibana)

**Docker Compose version** (needs ~2 GB free RAM; stop monitoring first if your PC is tight)
```bash
docker compose -f docker-compose.yml -f docker-compose.logging.yml up -d --build
```
Open Kibana http://localhost:5601 → *Stack Management → Data Views → Create* → pattern `notes-logs-*` → *Discover*. You'll see app and database container logs.

**Kubernetes version** (needs `minikube start --memory 4096` or more)
```bash
kubectl apply -f k8s/logging/efk.yaml
minikube service kibana -n logging --url
```
Same data-view step (`logstash-*`). Fluentd runs on every node and ships all pod/container logs, including the notes pods.

## 10. Phase 9 - Security checklist (what's implemented)
- **SonarQube** code analysis (Jenkins stage, `sonar-project.properties`)
- **Trivy** image scanning in Jenkins (change `--exit-code 0` to `1` to fail builds on HIGH/CRITICAL)
- **Secure Docker image:** slim base, non-root numeric UID, no dev tools, healthcheck
- **Secrets:** Kubernetes `Secret`, `.env` kept out of Git, Ansible template with mode 0600, Terraform `sensitive` variables
- **Jenkins credentials store** for Sonar/Docker Hub/GitHub tokens (never hard-coded)
- **RBAC:** app ServiceAccount has no API access; read-only `notes-viewer` role
- **App security:** password hashing, CSRF protection, input validation, token-expiring API auth, per-user data isolation
- **Pod hardening:** `runAsNonRoot`, drop all capabilities, no privilege escalation, resource limits

## 11. Phase 10 - Blue-Green deployment
Two Deployments (`notes-app-blue`, `notes-app-green`) exist; the Service sends traffic to whichever colour its `version:` selector names. The navbar badge shows the colour, so you can *see* the switch.
```bash
scripts/switch-bluegreen.sh green      # edits manifests: Service -> green, green=2 pods, blue=0
kubectl apply -f k8s/app               # traffic switches instantly
scripts/switch-bluegreen.sh blue       # instant rollback
```
With Jenkins GitOps enabled, a new image is placed on the **idle** colour first (`scripts/gitops-update.sh`); you test it, then run the switch.

## 12. Phase 11 - GitOps with ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8443:443
# password (PowerShell: use [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(...)) ):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Open https://localhost:8443 (user `admin`). Edit `argocd/application.yaml` → set `repoURL` to your repo (must be pushed to GitHub; public repo is easiest), then:
```bash
kubectl apply -f argocd/application.yaml
```
Now **Git is the source of truth**: change replicas or the Service colour in `k8s/app`, `git push`, and ArgoCD syncs the cluster. Manual `kubectl` edits get reverted (self-heal) - great for the demo.
> Note: the manifests reference image `notes-app:1.0` which exists only inside your minikube. For the full loop, push to Docker Hub via Jenkins so the cluster can pull it.

## 13. Demo script (10-15 min video)
1. Show repo + branches/merge graph → 2. `git push` → Jenkins runs automatically → 3. image built + Trivy report + Sonar dashboard → 4. `kubectl get all -n notes`, scale, rolling update, rollback → 5. Ansible run → 6. `terraform apply` → 7. Grafana dashboard → 8. Kibana logs → 9. blue-green switch (badge colour changes) → 10. ArgoCD sync after a Git change.

## Troubleshooting
- **Port 5000 busy:** set `APP_PORT=5050` in `.env`.
- **App shows "Database not ready" in logs:** normal for a few seconds while PostgreSQL starts.
- **Pods `ErrImagePull`:** run `minikube image load notes-app:1.0` again (image only exists on your PC).
- **Pods Pending / PVC not bound:** `kubectl describe pvc -n notes`; the PV uses `hostPath` and works on minikube.
- **SonarQube won't start (Linux):** `sudo sysctl -w vm.max_map_count=262144`.
- **Elasticsearch exits:** not enough RAM - close other containers or raise Docker Desktop memory.
- **Jenkins `docker: permission denied`:** the compose file runs Jenkins as root for the lab; make sure `/var/run/docker.sock` is mounted.
