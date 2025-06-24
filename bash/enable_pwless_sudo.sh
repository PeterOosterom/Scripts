#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Ask for the username
read -p "Enter the username to enable passwordless sudo: " USER

# Check if user exists
if ! id "$USER" &>/dev/null; then
  echo "User '$USER' does not exist. Exiting."
  exit 1
fi

# Create sudoers file for the user
SUDOERS_FILE="/etc/sudoers.d/${USER}"

# Add user to sudoers with NOPASSWD for all commands
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"

# Set correct permissions
chmod 440 "$SUDOERS_FILE"

# Add user to wheel group
usermod -aG wheel "$USER"

echo "Passwordless sudo enabled for user ${USER}."
echo "User ${USER} added to the wheel group."
