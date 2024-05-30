#!/bin/env bash
ORANGE='\033[0;33m'
NC='\033[0m'

printf "${ORANGE}Spinning Down Deployment of Quay${NC}\n"
podman kube down manifests/deployment.yaml &>/dev/null

printf "${ORANGE}Removing secrets and volumes${NC}\n"
podman volume rm pgsql-db quay-storage quay-tls quay-config 2>/dev/null
podman secret rm quay-tls redis-secret quay-config pgsql-secret 2>/dev/null

printf "${ORANGE}removing unprivileged port configuration from /etc/sysctl.conf${NC}\n"
sudo sed -i '/net.ipv4.ip_unprivileged_port_start=80/d' /etc/sysctl.conf

printf "${ORANGE}Removing self-signed cert (quay-selfsigned.crt) from trust anchors${NC}\n"
sudo rm /etc/pki/ca-trust/source/anchors/quay-selfsigned.crt 2>/dev/null
sudo update-ca-trust

# Force remove pod if stuck
printf "${ORANGE}Removing any lingering artifacts (pods)${NC}\n"
podman pod kill quay-pod 2>/dev/null
podman pod rm quay-pod 2>/dev/null
