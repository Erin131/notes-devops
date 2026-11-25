#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml -f docker-compose.logging.yml down
docker compose -f docker-compose.jenkins.yml down
echo "Stopped (data kept). Kubernetes: 'minikube stop' if needed."
