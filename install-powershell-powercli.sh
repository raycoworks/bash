#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to display usage information
usage() {
    echo "Usage: $0"
    exit 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root or use sudo."
  exit 1
fi

echo "Starting installation of PowerShell and VMware PowerCLI..."

# Step 1: Install dependencies required by both PowerShell Core and PowerCLI.
install_dependencies() {
    echo "Installing necessary packages..."
    
    # Update package lists
    apt-get update
    
    # Install prerequisites for downloading files over HTTPS, such as curl or wget
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        lsb-release

    echo "Dependencies installed."
}

# Step 2: Download and install PowerShell Core.
install_powershell() {
    echo "Installing PowerShell..."
    
    # Get the latest release from the repository
    PS_PACKAGE_URL=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep 'browser_download_url.*linux-x64.tar.gz' | cut -d '"' -f 4)
    
    if [ -z "$PS_PACKAGE_URL" ]; then
        echo "Failed to find PowerShell package URL. Exiting."
        exit 1
    fi

    # Download the latest release archive.
    curl -Lsfo /tmp/powershell.tar.gz $PS_PACKAGE_URL
    
    # Extract and install PowerShell to a system-wide location.
    mkdir -p /opt/microsoft/powershell/7
    tar zxfv /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7

    echo 'export PATH="$PATH:/opt/microsoft/powershell/7"' >> ~/.bashrc

    # Verify installation.
    pwsh --version
    
    echo "PowerShell installed successfully."
}

# Step 3: Install VMware PowerCLI.
install_powercli() {
    echo "Installing VMware PowerCLI..."

    # Download and install the PowerCLI module
    wget -qO- https://github.com/vmware/pvscmdlets/releases/latest | grep 'https.*zip' | cut -d '"' -f 4) |
        wget --no-check-certificate -i -
    
    unzip VMware.PowerCLI-latest.zip

    pwsh ./Install-PowerCLI.ps1
    
    echo "VMware PowerCLI installed successfully."
}

# Main script execution
install_dependencies
install_powershell
install_powercli

echo "Installation complete. PowerShell and VMware PowerCLI are ready to use."
