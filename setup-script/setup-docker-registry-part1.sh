#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage
usage() {
  echo "Usage: $0 --domain <DOMAIN> --port <PORT> --email <EMAIL> --username <USERNAME> --password <PASSWORD>"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --port) PORT="$2"; shift ;;
    --email) EMAIL="$2"; shift ;;
    --username) USERNAME="$2"; shift ;;
    --password) PASSWORD="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check if all required parameters are provided
if [ -z "$DOMAIN" ] || [ -z "$PORT" ] || [ -z "$EMAIL" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Error: Missing required parameters."
  usage
fi

# Save parameters for the second part of the script immediately
echo "Saving parameters for part 2..."
cat <<EOF >/tmp/setup-docker-registry-params.sh
DOMAIN="$DOMAIN"
PORT="$PORT"
EMAIL="$EMAIL"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF

# Continue with package updates and Docker installation
echo "Updating package lists..."
sudo apt-get update

# Install necessary packages
echo "Installing required packages..."
sudo apt-get install -y ca-certificates curl nginx apache2-utils certbot python3-certbot-nginx

# Set up Docker repository and install Docker
if ! [ -x "$(command -v docker)" ]; then
  echo "Setting up Docker repository and installing Docker..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl start docker
  sudo systemctl enable docker
  echo "Docker installed successfully."
else
  echo "Docker is already installed."
fi

# Apply Docker group permissions
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
  sudo usermod -aG docker $USER
  newgrp docker
  echo "Docker group permission applied. Please log out and log back in to apply the changes."
  echo "After re-login, run the following command to continue the setup:"
  echo "./setup-docker-registry-part2.sh"
  exit 0
else
  echo "User already has Docker group permissions."
fi

# Next steps instructions
echo "Please log out and log back in to apply Docker group changes."
echo "After re-login, run the following command to continue the setup:"
echo "./setup-docker-registry-part2.sh --domain $DOMAIN --port $PORT --email $EMAIL --username $USERNAME --password $PASSWORD"