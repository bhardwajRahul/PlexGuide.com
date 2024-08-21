#!/bin/bash

# Step 1: Create necessary directories
echo "Creating directories for Rclone configuration and cache..."
sudo mkdir -p ~/rclone/config
sudo mkdir -p ~/rclone/cache

# Step 2: Determine system architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected architecture: $ARCH"

# Step 3: Prompt the user for the Real-Debrid API key
read -p "Enter your Real-Debrid API key: " API_KEY

# Step 4: Install the Rclone Docker plugin
echo "Installing the Rclone Docker plugin..."
sudo docker plugin install itstoggle/docker-volume-rclone_rd:$ARCH args="-v" --alias rclone --grant-all-permissions config=~/rclone/config cache=~/rclone/cache

# Step 5: Create the Real-Debrid Docker volume using the provided API key
echo "Creating Real-Debrid Docker volume..."
sudo docker volume create realdebrid -d rclone -o type=realdebrid -o realdebrid-api_key="$API_KEY" -o allow-other=true -o dir-cache-time=10s

# Step 6: Verify the volume creation
echo "Verifying the Real-Debrid Docker volume..."
sudo docker run --rm -i -v=realdebrid:/tmp/myvolume busybox find /tmp/myvolume

echo -e "\nReal-Debrid Docker volume setup completed. You can now mount this volume into any Docker container."