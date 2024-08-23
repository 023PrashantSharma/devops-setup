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

echo "Setup complete. Your Next.js app is running and accessible at https://$DOMAIN"
