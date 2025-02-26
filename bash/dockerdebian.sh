#!/bin/bash

# Update package lists
apt-get update

# Install required packages
apt-get install -y ca-certificates curl

# Create keyrings directory if it doesn't exist
install -m 0755 -d /etc/apt/keyrings

# Download and store the Docker GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository to Apt sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again
apt-get update

# Download and store another GPG key for the repository
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null 

# Update package lists once more
apt-get update

# Install Docker packages
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Print installation success message
echo "Docker installation completed successfully."
