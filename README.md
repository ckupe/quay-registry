# quay-registry
Deploys a quay registry monolithic pod(s)

# Install

1. Ensure your system has unprivileged ports enabled so quay can bind to 443

```bash
sudo echo 'net.ipv4.ip_unprivileged_port_start=443' >> /etc/sysctl.conf
sudo sysctl -p
```


2. Ensure rootless podman is configured

```bash
sudo echo "$(whoami):999999:65536" >> /etc/subuid
sudo echo "$(whoami):999999:65536" >> /etc/subgid
sudo echo "user.max_user_namespaces=65536" >> /etc/sysctl.conf
sudo sysctl -p
```

3. Log into redhat.registry.io with podman
```bash
podman login registry.redhat.io
```

3. Install with script

```bash
# Don't do this as root!!
./install.sh
```

4. Add entry to /etc/hosts

```bash
sudo vi /etc/hosts
# Add your records:
# 
# 127.0.0.1 <fqdn of server hostname>

```

# Removal 

1. Run install script, which will remove all the podman volumes, secrets, and deployments.

```bash
./remove.sh
```

2. Remove entry from /etc/hosts

```bash
sudo vi /etc/hosts
```
