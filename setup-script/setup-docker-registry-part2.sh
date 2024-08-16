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

# Set up Docker registry
echo "Setting up Docker registry..."

# Create directory structure for Docker registry
mkdir -p ~/docker-registry/auth ~/docker-registry/data
cd ~/docker-registry

# Create Docker Compose file
echo "Creating docker-compose.yml..."
cat <<EOF >docker-compose.yml
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
    - "$PORT:5000"
    environment:
       REGISTRY_AUTH: htpasswd
       REGISTRY_AUTH_HTPASSWD_REALM: Registry
       REGISTRY_AUTH_HTPASSWD_PATH: /auth/registry.password
       REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
       - ./auth:/auth
       - ./data:/data
EOF

# Create htpasswd file for authentication
echo "Creating htpasswd file for authentication..."
sudo htpasswd -cb auth/registry.password "$USERNAME" "$PASSWORD"
sudo chown ubuntu:ubuntu auth/registry.password

# Set up Nginx
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 900;
    }
}
EOF

# Enable Nginx configuration and restart the service
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
echo "Nginx configured successfully."

# Obtain SSL certificate using Certbot
echo "Obtaining SSL certificate..."
if sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --redirect; then
  echo "SSL certificate obtained and Nginx configured."
else
  echo "Error: Failed to obtain SSL certificate." >&2
  exit 1
fi

# Start Docker registry using Docker Compose
echo "Starting Docker registry using Docker Compose..."
docker-compose up -d

if [ $? -eq 0 ]; then
  echo "Docker registry setup complete. Accessible at https://$DOMAIN"
else
  echo "Error: Docker registry setup failed." >&2
  exit 1
fi
