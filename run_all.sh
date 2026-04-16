#!/bin/bash

set -e

echo "=== Starting full deployment ==="

echo "Step 1: Terraform init"
terraform init

echo "Step 2: Terraform apply"
terraform apply -auto-approve

echo "Step 3: Install Docker"
ansible-playbook install_docker.yml

echo "Step 4: Run NGINX container"
ansible-playbook run_nginx.yml

echo "Step 5: Install PostgreSQL"
ansible-playbook install_postgres.yml

echo "Step 6: Install node_exporter"
ansible-playbook install_node_exporter.yml

echo "Step 7: Install monitoring (Prometheus + Grafana)"
ansible-playbook install_monitoring.yml

echo "=== Deployment completed successfully ==="
