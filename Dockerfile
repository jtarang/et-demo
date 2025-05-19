FROM debian:latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl systemctl openssh-server gnupg lsb-release jq unzip git nmap vim

# Add Eternal Terminal APT repo and GPG key (safe setup for Debian 12+)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://github.com/MisterTea/debian-et/raw/master/et.gpg | gpg --dearmor -o /etc/apt/keyrings/et.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/et.gpg] https://mistertea.github.io/debian-et/debian-source $(. /etc/os-release && echo $VERSION_CODENAME) main" \
    > /etc/apt/sources.list.d/et.list && \
    apt-get update && \
    apt-get install -y et


# Copy script into the container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run script at container startup
ENTRYPOINT ["/entrypoint.sh"]

