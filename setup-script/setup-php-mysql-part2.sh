#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Temp file to store parameters
TEMP_FILE="/tmp/setup-php-mysql-params.sh"

# Function to display usage
usage() {
  echo "Usage: $0 --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT> --db-port <DB_PORT> --email <EMAIL>"
  exit 1
}

# Function to save parameters to a temp file
save_params() {
  echo "DOMAIN='$DOMAIN'" > $TEMP_FILE
  echo "CONTAINER_NAME='$CONTAINER_NAME'" >> $TEMP_FILE
  echo "IMAGE_NAME='$IMAGE_NAME'" >> $TEMP_FILE
  echo "PORT='$PORT'" >> $TEMP_FILE
  echo "DB_PORT='$DB_PORT'" >> $TEMP_FILE
  echo "EMAIL='$EMAIL'" >> $TEMP_FILE
}

# Function to load parameters from a temp file
load_params() {
  if [ -f $TEMP_FILE ]; then
    source $TEMP_FILE
  else
    echo "Error: Temp file with parameters not found." >&2
    exit 1
  fi
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

# Debugging: Print out parameters
echo "DEBUG: DOMAIN=$DOMAIN"
echo "DEBUG: CONTAINER_NAME=$CONTAINER_NAME"
echo "DEBUG: IMAGE_NAME=$IMAGE_NAME"
echo "DEBUG: PORT=$PORT"
echo "DEBUG: DB_PORT=$DB_PORT"
echo "DEBUG: EMAIL=$EMAIL"

# Check if all required parameters are provided
if [ -z "$DOMAIN" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$IMAGE_NAME" ] || [ -z "$PORT" ] || [ -z "$EMAIL" ] || [ -z "$DB_PORT" ]; then
  echo "Error: Missing required parameters."
  usage
fi

# Save parameters to temp file
save_params

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

# Apply Docker group permissions without requiring a re-login
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
  sudo usermod -aG docker $USER
  echo "Docker group permission applied."

  # Pause and inform user to re-login
  echo "Please log out and log back in to apply Docker group changes."
  exit 0
fi

# Load parameters from temp file
load_params

# Debugging: Print out parameters after re-login
echo "DEBUG: DOMAIN=$DOMAIN"
echo "DEBUG: CONTAINER_NAME=$CONTAINER_NAME"
echo "DEBUG: IMAGE_NAME=$IMAGE_NAME"
echo "DEBUG: PORT=$PORT"
echo "DEBUG: DB_PORT=$DB_PORT"
echo "DEBUG: EMAIL=$EMAIL"

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

    location /phpmyadmin {
        proxy_pass http://localhost:$DB_PORT;
        proxy_set_header X-Script-Name /phpmyadmin;
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

# Prepare Docker environment variables
cat <<EOF > .env
MYSQL_ROOT_PASSWORD=my-secret-pw
MYSQL_DATABASE=mydatabase
MYSQL_USER=myuser
MYSQL_PASSWORD=mypassword
EOF

# Docker Compose setup
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  php:
    image: php:7.4-apache
    container_name: $CONTAINER_NAME
    ports:
      - "$PORT:80"
    volumes:
      - ./src:/var/www/html
    environment:
      - MYSQL_HOST=db
      - MYSQL_DATABASE=\${MYSQL_DATABASE}
      - MYSQL_USER=\${MYSQL_USER}
      - MYSQL_PASSWORD=\${MYSQL_PASSWORD}

  db:
    image: mysql:5.7
    ports:
      - "$DB_PORT:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=\${MYSQL_DATABASE}
      - MYSQL_USER=\${MYSQL_USER}
      - MYSQL_PASSWORD=\${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
      - "8080:80"
    environment:
      - PMA_HOST=db
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}

volumes:
  db_data:
EOF

# Build and start Docker containers
docker-compose up -d

if [ $? -eq 0 ]; then
  echo "Docker containers for $IMAGE_NAME built and started successfully."
else
  echo "Error: Failed to build and start Docker containers." >&2
  exit 1
fi

# Cleanup temporary file
rm $TEMP_FILE
echo "Temporary file $TEMP_FILE deleted."
