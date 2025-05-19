#!/bin/bash

set +x

install_teleport() {
    curl "https://${TELEPORT_ADDRESS}/scripts/install.sh" | bash
    echo "${TELEPORT_JOIN_TOKEN}" > /tmp/token
}

configure_teleport_yaml() {
    mkdir -p /etc
    cat <<EOF >/etc/teleport.yaml
version: v3
teleport:
  auth_token: /tmp/token
  proxy_server: ${TELEPORT_ADDRESS}
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
    format:
      output: text
ssh_service:
  enabled: true
  labels:
    env: ${ENVIRONMENT_TAG}
proxy_service:
  enabled: false
auth_service:
  enabled: false
EOF
}

install_teleport
configure_teleport_yaml


# Start Services
systemctl enable ssh
systemctl start ssh
systemctl start et
teleport start --config=/etc/teleport.yaml
