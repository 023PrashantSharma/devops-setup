#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Load parameters from part 1
if [ -f /tmp/setup-docker-registry-params.sh ]; then
  source /tmp/setup-docker-registry-params.sh
else
  echo "Error: Parameters file not found. Ensure the first script ran successfully." >&2
  exit 1
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
mkdir -p ~/docker-registry/auth
cd ~/docker-registry/auth
echo "$PASSWORD" | sudo htpasswd -B -c ~/docker-registry/auth/registry.password "$USERNAME"

sudo chown ubuntu:ubuntu ~/docker-registry/auth/registry.password
sudo chmod 644 ~/docker-registry/auth/registry.password

# Update Nginx configuration file
echo "Updating Nginx configuration file..."
sudo sed -i '/http {/a \    client_max_body_size 16384m;' /etc/nginx/nginx.conf

# Set up Nginx site
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

# Navigate to the Docker registry directory
cd ~/docker-registry

# Start Docker registry using Docker Compose
echo "Starting Docker registry using Docker Compose..."
docker compose up -d

if [ $? -eq 0 ]; then
  echo "Docker registry setup complete. Accessible at https://$DOMAIN"
else
  echo "Error: Docker registry setup failed." >&2
  exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -f /tmp/setup-docker-registry-params.sh
echo "Temporary files removed."
