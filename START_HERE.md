# START HERE (easy mode)

Install **Docker Desktop** first (open it and wait until it says "running"). Then double-click the files in the `easy` folder, in order. Take a screenshot after each one for your report.

| Double-click | What you get | Marks |
|---|---|---|
| `easy\1-run-app.bat` | The app at http://localhost:5000 (register, add notes) | 15 |
| `easy\2-run-tests.bat` | Automatic tests pass | |
| `easy\3-jenkins-sonar.bat` | Jenkins (8080) + SonarQube (9000) - then follow README section 4 | 10 |
| `easy\4-kubernetes.bat` | App on Kubernetes (needs minikube + kubectl installed) | 15 |
| `easy\5-monitoring.bat` | Grafana graphs (3000) | 5 |
| `easy\6-logging.bat` | Kibana logs (5601) | |
| `easy\7-terraform.bat` | Terraform builds the app (needs Terraform installed) | 10 |
| `easy\stop-everything.bat` | Frees your RAM - run it between steps | |

**Not one-click (copy-paste from README):** Git/GitHub (section 2), Kubernetes scale/update/rollback (5), Ansible (6, needs WSL), Blue-Green (11), ArgoCD (12).

Rule: run **one step at a time**, screenshot, run `stop-everything.bat`, next step.
Stuck? Tell me the step number and the error text.

---
## Kali / Linux easy mode
Open a terminal in the project folder and run these in order (one at a time, screenshot after each):

```
chmod +x easy/kali/*.sh
./easy/kali/01-app.sh          # app on :5000
./easy/kali/02-tests.sh        # 12 passed
./easy/kali/03-git.sh          # push to GitHub
./easy/kali/03b-conflict.sh    # merge conflict demo
./easy/kali/04-jenkins.sh      # Jenkins + SonarQube
./easy/kali/05-kubernetes.sh   # minikube + deploy
./easy/kali/06-k8s-demo.sh     # scale, update, rollback, RBAC
./easy/kali/07-bluegreen.sh green
./easy/kali/08-monitoring.sh   # Grafana
./easy/kali/09-logging.sh      # Kibana
./easy/kali/10-terraform.sh
./easy/kali/11-ansible.sh
./easy/kali/12-argocd.sh
./easy/kali/stop-all.sh        # run between big steps to free RAM
```
