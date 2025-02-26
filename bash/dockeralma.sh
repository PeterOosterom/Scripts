#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Update system package repositories
sudo dnf --refresh update -y
sudo dnf upgrade -y

# Install yum-utils for repository management
sudo dnf install -y yum-utils

# Add Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker and dependencies
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Confirm Docker installation
docker --version
echo "Docker installation completed successfully."
