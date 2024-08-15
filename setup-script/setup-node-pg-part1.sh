#!/bin/bash

# Temp file to store parameters
TEMP_FILE="/tmp/setup-node-pg-params.sh"

# Function to save parameters to a temp file
save_params() {
  echo "DOMAIN='$DOMAIN'" > $TEMP_FILE
  echo "CONTAINER_NAME='$CONTAINER_NAME'" >> $TEMP_FILE
  echo "IMAGE_NAME='$IMAGE_NAME'" >> $TEMP_FILE
  echo "PORT='$PORT'" >> $TEMP_FILE
  echo "DB_PORT='$DB_PORT'" >> $TEMP_FILE
  echo "EMAIL='$EMAIL'" >> $TEMP_FILE
}

# Function to display usage
usage() {
  echo "Usage: $0 --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT> --db-port <DB_PORT> --email <EMAIL>"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --container-name) CONTAINER_NAME="$2"; shift ;;
    --image-name) IMAGE_NAME="$2"; shift ;;
    --port) PORT="$2"; shift ;;
    --db-port) DB_PORT="$2"; shift ;;
    --email) EMAIL="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check if all required parameters are provided
if [ -z "$DOMAIN" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$IMAGE_NAME" ] || [ -z "$PORT" ] || [ -z "$EMAIL" ] || [ -z "$DB_PORT" ]; then
  echo "Error: Missing required parameters."
  usage
fi

# Save parameters to temp file
save_params

# Update package lists
sudo apt-get update

# Install Docker if not installed
if ! [ -x "$(command -v docker)" ]; then
  echo 'Installing Docker...'
  sudo apt-get install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
  echo 'Docker installed successfully.'
else
  echo 'Docker is already installed.'
fi

# Apply Docker group permissions and exit to allow re-login
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
  sudo usermod -aG docker $USER
  echo "Docker group permission applied."
  newgrp docker
  echo "Please log out and log back in to apply Docker group changes."
  exit 0
fi

# Run Part 2 of the script if Docker group permission was already set
bash setup-node-pg-part2.sh
