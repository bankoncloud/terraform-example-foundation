#!/bin/bash
set -e
echo "Installing nginx..."
sudo apt update
sudo apt install -y nginx
sudo ufw allow '${ufw_allow_nginx}'
sudo systemctl enable nginx

vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "This page is served from: <code>$vm_hostname</code>" | \
     sudo tee /var/www/html/index.html


sudo systemctl restart nginx

echo "Installation of nginx completed!"
