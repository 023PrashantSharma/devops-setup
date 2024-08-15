#!/bin/bash

# Temp file to store parameters
TEMP_FILE="/tmp/setup-node-pg-params.sh"

# Function to load parameters from a temp file
load_params() {
  if [ -f $TEMP_FILE ]; then
    source $TEMP_FILE
  else
    echo "Error: Temp file with parameters not found." >&2
    exit 1
  fi
}

# Load parameters from temp file
load_params

# Debugging: Print out parameters after re-login
echo "DEBUG: DOMAIN=$DOMAIN"
echo "DEBUG: CONTAINER_NAME=$CONTAINER_NAME"
echo "DEBUG: IMAGE_NAME=$IMAGE_NAME"
echo "DEBUG: PORT=$PORT"
echo "DEBUG: DB_PORT=$DB_PORT"
echo "DEBUG: EMAIL=$EMAIL"

# Install Docker Compose if not installed
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Installing Docker Compose...'
  sudo curl -L "https://github.com/docker/compose/releases/download/2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo 'Docker Compose installed successfully.'
else
  echo 'Docker Compose is already installed.'
fi

# Install Nginx if not installed
if ! [ -x "$(command -v nginx)" ]; then
  echo 'Installing Nginx...'
  sudo apt-get install -y nginx
  sudo systemctl start nginx
  sudo systemctl enable nginx
  echo 'Nginx installed successfully.'
else
  echo 'Nginx is already installed.'
fi

# Install Certbot for SSL if not installed
if ! [ -x "$(command -v certbot)" ]; then
  echo 'Installing Certbot...'
  sudo apt-get install -y certbot python3-certbot-nginx
  echo 'Certbot installed successfully.'
else
  echo 'Certbot is already installed.'
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

# Remove the temp file
rm -f $TEMP_FILE

echo "Setup complete. Your Node.js app is running and accessible at https://$DOMAIN"
