#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

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
  sudo curl -L "https://github.com/docker/compose/releases/download/2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo 'Docker Compose installed successfully.'
else
  echo 'Docker Compose is already installed.'
fi

# Install Nginx
if ! [ -x "$(command -v nginx)" ]; then
  echo 'Installing Nginx...'
  sudo apt-get install -y nginx --fix-missing
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

# Apply Docker group permissions without requiring a re-login
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
  sudo usermod -aG docker $USER
  echo "Docker group permission applied."

  # Restart the script with the updated group membership
  exec sg docker "$0 $*"
else
  echo "User already has Docker group permissions."
fi

# Test Docker permissions
if docker run hello-world &>/dev/null; then
  echo "Docker permission set successfully."
else
  echo "Error: Docker permission setup failed. Please re-login and run the script again." >&2
  exit 1
fi

# Configure Nginx
echo "Configuring Nginx..."
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

    location /pgadmin {
        proxy_pass http://localhost:$DB_PORT;
        proxy_set_header X-Script-Name /pgadmin;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
}
EOF

# Enable the new Nginx configuration
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

if [ $? -eq 0 ]; then
  echo "Nginx configuration for $DOMAIN created and enabled."
else
  echo "Error: Nginx configuration failed." >&2
  exit 1
fi

# Obtain SSL certificate using Certbot
echo "Obtaining SSL certificate..."
if sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --redirect; then
  echo "SSL certificate obtained and Nginx configured."
else
  echo "Error: Failed to obtain SSL certificate." >&2
  exit 1
fi

echo "Setup complete. Your Node.js app is running and accessible at https://$DOMAIN"
