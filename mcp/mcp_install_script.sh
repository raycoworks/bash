#!/bin/bash

# MCP Server Installation Script for Ubuntu 24.04
# This script installs MCP server without requiring a Claude API token
# along with all necessary dependencies

set -e  # Exit immediately if a command exits with a non-zero status

# Function to print colored text
print_status() {
    echo -e "\e[1;34m[*] $1\e[0m"
}

print_success() {
    echo -e "\e[1;32m[+] $1\e[0m"
}

print_error() {
    echo -e "\e[1;31m[-] $1\e[0m"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root using sudo"
    exit 1
fi

# Capture the actual username (not root)
if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
else
    USERNAME="$USER"
fi

# Detect user home directory
USER_HOME=$(eval echo ~$USERNAME)

# Update package lists
print_status "Updating package lists..."
apt update -y
print_success "Package lists updated"

# Install essential tools
print_status "Installing essential tools and dependencies..."
apt install -y build-essential curl wget git unzip software-properties-common \
    apt-transport-https ca-certificates gnupg lsb-release tmux htop
print_success "Essential tools installed"

# Install Python 3.10+ and pip
print_status "Installing Python and pip..."
apt install -y python3 python3-pip python3-venv python3-dev
print_success "Python installed: $(python3 --version)"

# Install Node.js and npm
print_status "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
print_success "Node.js installed: $(node --version)"
print_success "npm installed: $(npm --version)"

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://get.docker.com | bash
systemctl enable docker
systemctl start docker
usermod -aG docker $USERNAME
print_success "Docker installed: $(docker --version)"

# Install Docker Compose
print_status "Installing Docker Compose..."
apt install -y docker-compose
print_success "Docker Compose installed: $(docker-compose --version)"

# Create a directory for MCP
MCP_DIR="$USER_HOME/mcp-server"
print_status "Creating MCP directory at $MCP_DIR..."
mkdir -p "$MCP_DIR"
chown -R $USERNAME:$USERNAME "$MCP_DIR"

# Clone the MCP repository
print_status "Cloning MCP Server repository..."
cd "$MCP_DIR"
sudo -u $USERNAME git clone https://github.com/anthropics/anthropic-cookbook.git ./anthropic-cookbook
print_success "MCP repository cloned"

# Set up Python virtual environment
print_status "Setting up Python virtual environment..."
cd "$MCP_DIR"
sudo -u $USERNAME python3 -m venv venv
sudo -u $USERNAME bash -c "source venv/bin/activate && pip install --upgrade pip"
print_success "Python virtual environment created"

# Install Python dependencies
print_status "Installing Python dependencies..."
cd "$MCP_DIR"
sudo -u $USERNAME bash -c "source venv/bin/activate && pip install anthropic fastapi uvicorn pydantic python-dotenv"
print_success "Python dependencies installed"

# Configure MCP server settings
print_status "Configuring MCP server settings..."
cd "$MCP_DIR"
sudo -u $USERNAME bash -c "cat > .env << EOF
# MCP Server Configuration
PORT=8000
HOST=0.0.0.0
LOG_LEVEL=info
# Running without a Claude API token in local-only mode
ENABLE_LOCAL_MODE=true
EOF"
print_success "MCP server settings configured"

# Create a basic MCP server file
print_status "Creating MCP server file..."
cd "$MCP_DIR"
sudo -u $USERNAME bash -c "cat > mcp_server.py << EOF
import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = FastAPI(title='MCP Server')

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

@app.get('/')
async def root():
    return {'status': 'MCP server running in local mode'}

@app.get('/health')
async def health_check():
    return {'status': 'healthy'}

# Add your custom endpoints here

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8000))
    host = os.getenv('HOST', '0.0.0.0')
    uvicorn.run('mcp_server:app', host=host, port=port, reload=True)
EOF"
print_success "MCP server file created"

# Create a systemd service file for MCP
print_status "Creating systemd service for MCP..."
cat > /etc/systemd/system/mcp.service << EOF
[Unit]
Description=MCP Server
After=network.target

[Service]
User=$USERNAME
WorkingDirectory=$MCP_DIR
ExecStart=$MCP_DIR/venv/bin/python mcp_server.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mcp-server
Environment="PATH=$MCP_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mcp.service
print_success "MCP systemd service created and enabled"

# Create startup and management scripts
print_status "Creating startup and management scripts..."
cd "$MCP_DIR"

# Start script
sudo -u $USERNAME bash -c "cat > start_mcp.sh << EOF
#!/bin/bash
cd $MCP_DIR
source venv/bin/activate
python mcp_server.py
EOF"

# Stop script
sudo -u $USERNAME bash -c "cat > stop_mcp.sh << EOF
#!/bin/bash
pkill -f 'python mcp_server.py' || echo 'MCP server is not running'
EOF"

# Make scripts executable
sudo -u $USERNAME chmod +x start_mcp.sh stop_mcp.sh
print_success "Management scripts created"

# Set proper permissions
print_status "Setting proper permissions..."
chown -R $USERNAME:$USERNAME "$MCP_DIR"
print_success "Permissions set"

# Final message
print_success "========================================================"
print_success "MCP Server installation completed!"
print_success "========================================================"
print_success "The MCP server is installed at: $MCP_DIR"
print_success "To start the server manually: sudo systemctl start mcp"
print_success "To stop the server: sudo systemctl stop mcp"
print_success "To check server status: sudo systemctl status mcp"
print_success "========================================================"
print_success "You can also use the following management scripts:"
print_success "Start server: $MCP_DIR/start_mcp.sh"
print_success "Stop server: $MCP_DIR/stop_mcp.sh"
print_success "========================================================"
print_success "MCP server will be accessible at: http://localhost:8000"
print_success "========================================================"

# Start the service
print_status "Starting MCP service..."
systemctl start mcp.service
print_success "MCP service started"

exit 0
