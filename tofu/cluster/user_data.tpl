#cloud-config

locale: en_US.UTF-8
timezone: Europe/Berlin

write_files:
- path: /etc/rancher/k3s/token
  permissions: "0600"
  content: "${token}"
- path: /etc/rancher/k3s/config.yaml
  permissions: "0600"
  content: |
    %{ if role == "control-plane" }
    cluster-init: true
    tls-san:
    - ${control_plane_ip}
    %{ else }
    server: "https://${control_plane_ip}:6443"
    %{ endif }
    token-file: /etc/rancher/k3s/token
    node-external-ip: ${node_ip}
- path: /opt/install-k3s.sh
  permissions: "0700"
  content: |
    #!/bin/bash
    echo "Installing k3s (${role})"

    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="v1.34" sh -s - %{ if role == "control-plane" }server%{ else }agent%{ endif }

runcmd:
- /opt/install-k3s.sh
