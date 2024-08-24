#!/bin/bash

# ANSI color codes for formatting
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No color

# Function to check and install unzip if not present
check_and_install_unzip() {
    if ! command -v unzip &> /dev/null; then
        echo "unzip not found. Installing unzip..."
        sudo apt-get update
        sudo apt-get install -y unzip
        echo "unzip has been installed."
    fi
}

# Function to fetch all releases from GitHub and filter them
fetch_releases() {
    curl -s https://api.github.com/repos/plexguide/PlexGuide.com/releases | jq -r '.[].tag_name' | grep -E '^11\.[0-9]\.B[0-9]+' | sort -r | head -n 50
}

# Function to prepare directories
prepare_directories() {
    # Define directories to create
    directories=(
        "/pg/config"
        "/pg/scripts"
        "/pg/apps"
        "/pg/stage"
    )

    # Loop through the directories and create them with the correct permissions
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            echo "Created $dir"
        else
            echo "$dir already exists"
        fi
        # Clear the directory if it is /pg/stage, /pg/scripts, or /pg/apps
        if [[ "$dir" == "/pg/stage" || "$dir" == "/pg/scripts" || "$dir" == "/pg/apps" ]]; then
            rm -rf "${dir:?}"/*
            echo "Cleared $dir directory."
        fi
        # Set ownership to user with UID and GID 1000
        chown -R 1000:1000 "$dir"
        # Set the directories as executable
        chmod -R +x "$dir"
    done
}

# Function to download and extract the selected release
download_and_extract() {
    local selected_version="$1"
    local url="https://github.com/plexguide/PlexGuide.com/archive/refs/tags/${selected_version}.zip"
    
    echo "Downloading and extracting ${selected_version}..."
    
    # Download the zip file into /pg/stage
    curl -L -o /pg/stage/release.zip "$url"
    
    # Unzip the contents directly into /pg/stage
    unzip -o /pg/stage/release.zip -d /pg/stage/
    
    # Find the extracted folder
    local extracted_folder="/pg/stage/PlexGuide.com-${selected_version}"
    
    # Check if the folder exists and move the contents if it does
    if [[ -d "$extracted_folder" ]]; then
        echo "Found extracted folder: $extracted_folder"
        if [[ -d "$extracted_folder/mods/apps" ]]; then
            echo "Moving apps to /pg/apps"
            mv "$extracted_folder/mods/apps/"* /pg/apps/
            # Set ownership and permissions
            chown -R 1000:1000 /pg/apps/
            chmod -R +x /pg/apps/
        else
            echo "No apps directory found in $extracted_folder"
        fi
        
        if [[ -d "$extracted_folder/mods/scripts" ]]; then
            echo "Moving scripts to /pg/scripts"
            mv "$extracted_folder/mods/scripts/"* /pg/scripts/
            # Set ownership and permissions
            chown -R 1000:1000 /pg/scripts/
            chmod -R +x /pg/scripts/
        else
            echo "No scripts directory found in $extracted_folder"
        fi

        # Execute menu_commands.sh script after moving files
        if [[ -f "/pg/apps/menu_commands.sh" ]]; then
            echo "Executing menu_commands.sh"
            bash /pg/apps/menu_commands.sh
        fi

        # Clear the /pg/stage directory after moving the files
        rm -rf /pg/stage/*
        echo "Cleared /pg/stage directory after moving files."
        
    else
        echo "Extracted folder $extracted_folder not found!"
    fi
    
    echo "Files for ${selected_version} have been processed."
}

# Function to update the version in the config file
update_config_version() {
    local selected_version="$1"
    local config_file="/pg/config/config.cfg"

    # Check if the config file exists, create if not
    if [[ ! -f "$config_file" ]]; then
        echo "Creating config file at $config_file"
        touch "$config_file"
    fi

    # Update or add the VERSION variable in the config file
    if grep -q "^VERSION=" "$config_file"; then
        sed -i "s/^VERSION=.*/VERSION=\"$selected_version\"/" "$config_file"
    else
        echo "VERSION=\"$selected_version\"" >> "$config_file"
    fi

    echo "VERSION has been set to $selected_version in $config_file"
}

# Function to display releases
display_releases() {
    releases="$1"
    echo -e "${RED}PG Beta Releases:${NC}"
    echo ""
    line_length=0
    for release in $releases; do
        if (( line_length + ${#release} + 2 > 80 )); then
            echo ""
            line_length=0
        fi
        echo -n "$release, "
        line_length=$((line_length + ${#release} + 2))
    done
    echo "" # New line after displaying all releases
}

# Main logic
while true; do
    clear
    releases=$(fetch_releases)
    
    if [[ -z "$releases" ]]; then
        echo "No releases found starting with '11' and containing 'B'."
        exit 1
    fi

    display_releases "$releases"
    echo ""
    read -p "Which version do you want to install? " selected_version

    if echo "$releases" | grep -q "^${selected_version}$"; then
        echo ""
        read -p "$(echo -e "Type [${RED}1234${NC}] to accept or [${GREEN}Z${NC}] to cancel: ")" response
        if [[ "$response" == "1234" ]]; then
            check_and_install_unzip
            prepare_directories
            download_and_extract "$selected_version"
            update_config_version "$selected_version"
            break
        elif [[ "${response,,}" == "z" ]]; then
            echo "Installation canceled."
            exit 0
        else
            clear
        fi
    else
        clear
        echo "Invalid version. Please select a valid version from the list."
    fi
done

# Execute plexguide
echo "Starting PlexGuide..."
plexguide