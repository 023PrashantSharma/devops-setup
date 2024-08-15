
# DevOps Essential Setup

[![License](https://img.shields.io/github/license/023PrashantSharma/devops-setup)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/023PrashantSharma/devops-setup)](https://github.com/023PrashantSharma/devops-setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/023PrashantSharma/devops-setup)](https://github.com/023PrashantSharma/devops-setup/network)
[![GitHub issues](https://img.shields.io/github/issues/023PrashantSharma/devops-setup)](https://github.com/023PrashantSharma/devops-setup/issues)
[![GitHub contributors](https://img.shields.io/github/contributors/023PrashantSharma/devops-setup)](https://github.com/023PrashantSharma/devops-setup/graphs/contributors)
[![Script Usage](https://img.shields.io/badge/Script%20Usage-0-brightgreen)](https://github.com/023PrashantSharma/devops-setup)

Welcome to the **DevOps Essential Setup** repository! This repository contains essential scripts and configurations to streamline the setup of various types of projects on the cloud. It simplifies the process of setting up Docker, Nginx, SSL, and other DevOps tools, ensuring a smoother and more efficient deployment process.

## Features

- **Easy Docker Installation**: Quickly set up Docker on your server.
- **Nginx Configuration**: Automate the configuration of Nginx to serve your applications.
- **SSL Certificate Installation**: Secure your applications with automated SSL installation using Certbot.
- **Customizable Scripts**: Pass variables directly to the script for flexible and universal setups.

## Usage

If you want to clone the entire repository and use the scripts:

1. **Clone the Repository**

   ```sh
   git clone https://github.com/023PrashantSharma/devops-setup.git
   cd devops-setup
   ```

2. **Setup nextjs project**

   - Clone and run the setup script:
   ```sh
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/main/setup-script/setup-nextjs.sh
   chmod +x setup-nextjs.sh
   ./setup-nextjs.sh --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT> --email <EMAIL>
   ```
   - Clone the Dockerfile and \`cicd.yml\` file for setting up GitHub workflows:
   ```sh
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/tree/main/github-workflow/nextjs/Dockerfile
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/tree/main/github-workflow/nextjs/cicd.yml
   ```

3. **Setup node-postgres project**

   - Run the initial setup script:
   ```sh
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/main/setup-script/setup-node-pg-part1.sh
   chmod +x setup-node-pg-part1.sh
   ./setup-node-pg-part1.sh --domain <DOMAIN> --container-name <CONTAINER_NAME> --image-name <IMAGE_NAME> --port <PORT> --db-port <DB_PORT> --email <EMAIL>
   ```
   - **Important:** After running the above script, log out and log back in to apply Docker group changes.
   
   - Run the follow-up script after logging back in:
   ```sh
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/main/setup-script/setup-node-pg-part2.sh
   chmod +x setup-node-pg-part2.sh
   ./setup-node-pg-part2.sh
   ```

   - Clone the Dockerfile and \`cicd.yml\` file for setting up GitHub workflows:
   ```sh
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/main/github-workflow/node-postgres/Dockerfile
   curl -O https://raw.githubusercontent.com/023PrashantSharma/devops-setup/main/github-workflow/node-postgres/cicd.yml
   ```
