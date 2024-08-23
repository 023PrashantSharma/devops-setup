#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage
usage() {
  echo "Usage: $0 --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT> --email <EMAIL>"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --container-name) CONTAINER_NAME="$2"; shift ;;
    --image-name) IMAGE_NAME="$2"; shift ;;
    --port) PORT="$2"; shift ;;
    --email) EMAIL="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check if all required parameters are provided
if [ -z "$DOMAIN" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$IMAGE_NAME" ] || [ -z "$PORT" ] || [ -z "$EMAIL" ]; then
  echo "Error: Missing required parameters."
  usage
fi

echo "Updating package lists..."
sudo apt-get update

# Install Docker
if ! [ -x "$(command -v docker)" ]; then
  echo 'Installing Docker...'
  sudo apt-get install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
  echo 'Docker installed successfully.'
else
  echo 'Docker is already installed.'
fi

# Install Docker Compose
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Installing Docker Compose...'
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo 'Docker Compose installed successfully.'
else
  echo 'Docker Compose is already installed.'
fi

# Install Nginx
if ! [ -x "$(command -v nginx)" ]; then
  echo 'Installing Nginx...'
  sudo apt-get install -y nginx
  sudo systemctl start nginx
  sudo systemctl enable nginx
  echo 'Nginx installed successfully.'
else
  echo 'Nginx is already installed.'
fi

# Install Certbot for SSL
if ! [ -x "$(command -v certbot)" ]; then
  echo 'Installing Certbot...'
  sudo apt-get install -y certbot python3-certbot-nginx
  echo 'Certbot installed successfully.'
else
  echo 'Certbot is already installed.'
fi

# Apply Docker group permissions
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
  sudo usermod -aG docker $USER
  echo "Docker group permission applied."
  newgrp docker
  echo "Docker group permission applied."
  exit 0
else
  echo "User already has Docker group permissions."
fi
# Run Part 2 of the script if Docker group permission was already set
bash setup-nextjs-part2.sh --domain $DOMAIN --container-name $CONTAINER_NAME --image-name $IMAGE_NAME --port $PORT --email $EMAIL
