#!/bin/bash
# AppFoundation CLI Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/TomTheCattt/AppFoundationCLI/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CLI_NAME="appfoundation"
REPO_URL="https://github.com/TomTheCattt/AppFoundationCLI.git"
CONFIG_DIR="$HOME/.appfoundation"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AppFoundation CLI Installer v1.0    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}✗ Please do not run as root${NC}"
    exit 1
fi

# Check dependencies
echo -e "${BLUE}→${NC} Checking dependencies..."

if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ jq is not installed (recommended)${NC}"
    echo -e "  Install with: brew install jq"
fi

echo -e "${GREEN}✓${NC} Dependencies OK"

# Create config directory
echo -e "${BLUE}→${NC} Creating configuration directory..."
mkdir -p "$CONFIG_DIR"/{cache,logs}
echo -e "${GREEN}✓${NC} Created $CONFIG_DIR"

# Create default config
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cat > "$CONFIG_DIR/config.json" <<EOF
{
  "remote": "https://github.com/TomTheCattt/AppFoundation.git",
  "defaultBranch": "main",
  "cacheDir": "$CONFIG_DIR/cache",
  "autoUpdate": true,
  "checkUpdateInterval": "daily",
  "lastUpdateCheck": ""
}
EOF
    echo -e "${GREEN}✓${NC} Created default config"
fi

# Download CLI
if [ -d "$INSTALL_DIR/$CLI_NAME" ]; then
    echo -e "${BLUE}→${NC} Updating AppFoundation CLI..."
else
    echo -e "${BLUE}→${NC} Downloading AppFoundation CLI..."
fi

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone repository
git clone --depth 1 "$REPO_URL" appfoundation-cli 2>/dev/null || {
    echo -e "${RED}✗ Failed to download CLI${NC}"
    exit 1
}

# Install main executable
echo -e "${BLUE}→${NC} Installing executable..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp appfoundation-cli/bin/appfoundation "$INSTALL_DIR/$CLI_NAME"
sudo chmod +x "$INSTALL_DIR/$CLI_NAME"

# Copy library files
LIB_DIR="$CONFIG_DIR/lib"
mkdir -p "$LIB_DIR"
cp -r appfoundation-cli/lib/* "$LIB_DIR/"

# Cleanup
cd -
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓${NC} Installation complete!"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation Success!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Run ${BLUE}$CLI_NAME --version${NC} to verify installation"
echo -e "Run ${BLUE}$CLI_NAME --help${NC} to see available commands"
echo ""
echo -e "Get started:"
echo -e "  ${BLUE}$CLI_NAME init MyApp${NC}"
echo ""
