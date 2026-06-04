#!/bin/bash
# Self-Hosted Platform: AWS K3s Bootstrap Script
set -e

# Update apt repositories and wait if apt lock is held
apt-get update -y
apt-get install -y curl ca-certificates

# Fetch the public IP address if not supplied, though we pass it via Terraform
PUBLIC_IP="${public_ip}"

# Install K3s
# --write-kubeconfig-mode 644 allows local clients (like our pipeline or local terminal) to fetch the kubeconfig
# --tls-san adds the Elastic IP to the TLS certs so we can run kubectl remotely
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --write-kubeconfig-mode 644 \
  --tls-san ${public_ip} \
  --disable traefik" sh -

# Wait for Kubeconfig to be generated
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  sleep 2
done

# Replace localhost with public IP in kubeconfig so it can be used externally
sed -i "s/127.0.0.1/${public_ip}/g" /etc/rancher/k3s/k3s.yaml

echo "K3s installation completed successfully!"
