#!/bin/bash

set -ex

# Function to safely modify sshd_config and apply permissions
configure_sshd() {
    echo "Configuring sshd_config for Teleport certificate authentication..."
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
    TELEPORT_USER_CA_PUB="/etc/ssh/teleport_user_ca.pub"

    # Make a backup of the original config file
    cp "${SSHD_CONFIG_FILE}" "${SSHD_CONFIG_FILE}.bak"

    # Fetch the Teleport User CA certificate and add it to TrustedUserCAKeys
    # IMPORTANT: Ensure TELEPORT_ADDRESS is correctly set and accessible.
    export KEY=$(curl -s "https://${TELEPORT_ADDRESS}/webapi/auth/export?type=user" | sed "s/cert-authority\ //")

    if [ -n "$KEY" ]; then
        echo "Adding Teleport User CA to sshd_config..."
        # Add or update TrustedUserCAKeys directive
        if grep -qE "^\s*#?\s*TrustedUserCAKeys" "${SSHD_CONFIG_FILE}"; then
            sed -i "s|^\s*#\?TrustedUserCAKeys.*|TrustedUserCAKeys ${TELEPORT_USER_CA_PUB}|" "${SSHD_CONFIG_FILE}"
        else
            echo "TrustedUserCAKeys ${TELEPORT_USER_CA_PUB}" >> "${SSHD_CONFIG_FILE}"
        fi

        # Write the CA certificate to the specified file
        echo "$KEY" > "${TELEPORT_USER_CA_PUB}"
        echo "Teleport User CA added to ${TELEPORT_USER_CA_PUB}"

        # Set correct permissions for the CA file
        chmod 644 "${TELEPORT_USER_CA_PUB}" # Read-only for others
        chown root:root "${TELEPORT_USER_CA_PUB}"
        echo "Permissions set for ${TELEPORT_USER_CA_PUB}"
    else
        echo "ERROR: Failed to fetch Teleport User CA. Ensure TELEPORT_ADDRESS is correct and Teleport is accessible."
        # Optionally, exit here if fetching the CA is critical for your SSH setup
        # exit 1
    fi

    # Ensure PermitRootLogin is set.
    if grep -qE "^\s*#?\s*PermitRootLogin" "${SSHD_CONFIG_FILE}"; then
        sed -i 's/^\s*#\?PermitRootLogin.*/PermitRootLogin without-password/' "${SSHD_CONFIG_FILE}"
    else
        echo "PermitRootLogin without-password" >> "${SSHD_CONFIG_FILE}"
    fi

    # Disable password authentication entirely for root (recommended if using keys)
    if grep -qE "^\s*#?\s*PasswordAuthentication" "${SSHD_CONFIG_FILE}"; then
        sed -i 's/^\s*#\?PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG_FILE}"
    else
        echo "PasswordAuthentication no" >> "${SSHD_CONFIG_FILE}"
    fi

    # Set correct permissions for sshd_config
    chmod 600 "${SSHD_CONFIG_FILE}"
    chown root:root "${SSHD_CONFIG_FILE}"

    echo "sshd_config configured."
}


install_ssh_service() {
    echo "SSH service not found or not running. Installing OpenSSH server..."
    apt-get update -y
    apt-get install -y openssh-server

    # Configure sshd after installation
    configure_sshd # Call the new function here

    echo "SSH service installed."
}

# New function to install and start Eternal Terminal
install_et() {
    echo "Installing Eternal Terminal..."
    # Add the ET repository key
    curl -fsSL https://packagecloud.io/install/repositories/eternal-terminal/et/script.deb.sh | bash
    # Update package lists and install et
    apt-get update -y
    apt-get install -y et

    echo "Eternal Terminal installed. Starting etserver..."
    # Start the etserver in daemon mode
    etserver --daemon
    echo "Eternal Terminal server started."
}


install_teleport() {
    echo "Installing Teleport..."
    curl "https://${TELEPORT_ADDRESS}/scripts/install.sh" | bash
    echo "${TELEPORT_JOIN_TOKEN}" > /tmp/token
    echo "Teleport installed."
}

configure_teleport_yaml() {
    echo "Configuring /etc/teleport.yaml..."
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
  listen_addr: 0.0.0.0:3022
  labels:
    env: ${ENVIRONMENT_TAG}
proxy_service:
  enabled: false
auth_service:
  enabled: false
EOF
    echo "Teleport configuration complete."
}

# Main execution flow
install_ssh_service
install_et # Call the new ET installation function
install_teleport
configure_teleport_yaml

# Final restart of sshd to ensure all changes are applied
echo "Attempting final restart of sshd..."
service ssh start

# Start Teleport
echo "Starting Teleport service..."
teleport start --config=/etc/teleport.yaml  # Run Teleport in background so entrypoint can continue