#!/bin/env bash
GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'

read -p "Desired Quay Hostname: " QUAY_HOSTNAME
export REDIS_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
export PGSQL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)

cat >/tmp/quay.config <<EOF
BUILDLOGS_REDIS:
    host: localhost
    password: $REDIS_PASSWORD
    port: 6379
CREATE_NAMESPACE_ON_PUSH: true
DATABASE_SECRET_KEY: a8c2744b-7004-4af2-bcee-e417e7bdd235
DB_URI: postgresql://quay:$PGSQL_PASSWORD@localhost:5432/quay
DISTRIBUTED_STORAGE_CONFIG:
    default:
        - LocalStorage
        - storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - default
FEATURE_MAILING: false
SECRET_KEY: e9bd34f4-900c-436a-979e-7530e5d74ac8
SERVER_HOSTNAME: $QUAY_HOSTNAME
PREFERRED_URL_SCHEME: https
SETUP_COMPLETE: true
USER_EVENTS_REDIS:
    host: localhost
    password: $REDIS_PASSWORD
    port: 6379
EOF

printf "${GREEN}Cleaning up leftover secrets${NC}\n"
podman secret rm quay-tls pgsql-secret redis-secret quay-config 2>/dev/null

printf "${GREEN}Generating secrets${NC}\n"
podman run --rm -i docker.io/d3fk/kubectl:latest create secret generic \
	--from-literal=password=$PGSQL_PASSWORD \
	pgsql-secret \
	--dry-run=client \
	-o yaml |
	podman kube play -

podman run --rm -i docker.io/d3fk/kubectl:latest create secret generic \
	--from-literal=password=$REDIS_PASSWORD \
	redis-secret \
	--dry-run=client \
	-o yaml |
	podman kube play -

podman run --rm -i -v /tmp/quay.config:/tmp/quay.config:z docker.io/d3fk/kubectl:latest \
	create secret generic \
	--from-file=/tmp/quay.config \
	quay-config \
	--dry-run=client \
	-o yaml |
	podman kube play -

printf "${GREEN}Generating Self-Signed Certificate for $QUAY_HOSTNAME ${NC}\n"
[[ ! -f certs/tls.crt ]] || rm -f certs/tls.key certs/tls.crt
openssl req -x509 -newkey rsa:4096 -keyout ./certs/tls.key -out ./certs/tls.crt -sha256 -days 3650 -nodes -nodes -subj "/CN=$QUAY_HOSTNAME" -addext "subjectAltName=DNS:$QUAY_HOSTNAME"

printf "${GREEN}Burning Cert+Key into secret ${NC}\n"
podman run --rm -i -v ./certs/tls.key:/tls.key:z -v ./certs/tls.crt:/tls.crt:z docker.io/d3fk/kubectl:latest \
	create secret tls \
	--cert=/tls.crt \
	--key=/tls.key \
	quay-tls \
	--dry-run=client \
	-o yaml |
	podman kube play -

printf "${GREEN}Showing all secrets: ${NC}\n"
podman secret ls

printf "\n${GREEN}Deploying Quay..${NC}\n"
podman kube play manifests/deployment.yaml

printf "\n${GREEN}Waiting 10 Seconds, then configuring PostgreSQL DB Module (TRGM)${NC}\n"
sleep 10 && podman exec quay-pod-pgsql /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U quay'

printf "\n${GREEN}Installing self-signed certificate to host trust anchors${NC}\n"
sudo cp certs/tls.crt /etc/pki/ca-trust/source/anchors/quay-selfsigned.crt
sudo update-ca-trust

printf "\n${CYAN}Deployment Complete! \nCheck Quay Logs with: \n     podman logs -f quay-pod-quay \n It's recommended you add an entry to /etc/hosts to resolve your desired name: $QUAY_HOSTNAME ${NC}\n"
