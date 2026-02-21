#!/bin/bash
# Test that build environment is working

set -e  # Exit on error

echo "================================"
echo "BFS Build Environment Test"
echo "================================"
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if command exists
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $1 found: $(command -v $1)"
        return 0
    else
        echo -e "${RED}✗${NC} $1 NOT FOUND"
        return 1
    fi
}

# Check all required tools
echo "Checking required tools..."
echo ""

check_command debootstrap
check_command mksquashfs
check_command xorriso
check_command qemu-system-x86_64
check_command git
check_command python3

echo ""
echo "Checking permissions..."

# Check if we can use sudo
if sudo -n true 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Sudo access available"
else
    echo -e "${RED}✗${NC} Sudo access required (you may need to enter password)"
    sudo echo -e "${GREEN}✓${NC} Sudo access confirmed"
fi

echo ""
echo "Checking disk space..."

AVAILABLE=$(df -h ~ | awk 'NR==2 {print $4}')
echo "Available space in home directory: $AVAILABLE"

echo ""
echo "================================"
echo -e "${GREEN}✓ Build environment ready!${NC}"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Create a minimal Debian base"
echo "2. Test QEMU boot"
echo "3. Build first prototype ISO"
