#!/bin/bash

set -e

echo "Starting Ansible deployment..."

ansible-playbook -i inventory.ini install_docker.yml
ansible-playbook -i inventory.ini run_nginx.yml
ansible-playbook -i inventory.ini install_postgres.yml

echo "Deployment finished successfully."
