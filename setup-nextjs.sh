#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT>"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --container-name) CONTAINER_NAME="$2"; shift ;;
    --image-name) IMAGE_NAME="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check if all required parameters are provided
if [ -z "$DOMAIN" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$IMAGE_NAME" ] || [ -z "$PORT" ]; then
  echo "Error: Missing required parameters."
  usage
fi

# Update package lists
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
# Apply permission
sudo usermod -aG docker $USER

# Reload permission
newgrp docker

# Test Run the Docker container
docker run hello-world

# Check if the container started successfully
if [ $? -eq 0 ]; then
  echo "Docker container started successfully."
  echo "Your docker permission set successfully"
else
  echo "Error: Failed to start the Docker container." >&2
  exit 1
fi

# Configure Nginx
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the new Nginx configuration
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "Nginx configuration for $DOMAIN created and enabled."

# Obtain SSL certificate using Certbot
sudo certbot --nginx -d $DOMAIN

echo "SSL certificate obtained and Nginx configured."

# Final message
echo "Setup complete. Your Next.js app is running and accessible at https://$DOMAIN"
