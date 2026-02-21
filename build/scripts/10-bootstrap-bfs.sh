#!/bin/bash
# Create the actual BFS Debian base system

set -e  # Exit on error

echo "================================"
echo "Creating BFS Base System"
echo "================================"
echo ""

# Configuration
BFS_ROOT="artifacts/bfs-root"
DEBIAN_VERSION="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian/"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Clean up old build if exists
if [ -d "$BFS_ROOT" ]; then
    echo "Removing old build..."
    sudo rm -rf "$BFS_ROOT"
fi

mkdir -p artifacts

echo -e "${BLUE}Stage 1: Bootstrap Debian base${NC}"
echo "This will take 5-10 minutes and download ~200MB"
echo ""

# Bootstrap with essential packages
sudo debootstrap \
    --variant=minbase \
    --include=systemd,udev,dbus,kmod,util-linux,procps \
    $DEBIAN_VERSION \
    $BFS_ROOT \
    $DEBIAN_MIRROR

echo ""
echo -e "${GREEN}✓ Bootstrap complete${NC}"
echo ""

# Configure basic system
echo -e "${BLUE}Stage 2: Configure base system${NC}"

# Set hostname
echo "bfs-rescue" | sudo tee $BFS_ROOT/etc/hostname > /dev/null

# Set hosts file
sudo bash -c "cat > $BFS_ROOT/etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   bfs-rescue
::1         localhost ip6-localhost ip6-loopback
HOSTS"

# Set root password to 'bfs' (temporary, for testing)
echo "Setting root password to 'bfs'..."
echo "root:bfs" | sudo chroot $BFS_ROOT chpasswd

echo -e "${GREEN}✓ Base system configured${NC}"
echo ""

# Show summary
echo "================================"
echo "BFS Base System Created"
echo "================================"
echo ""
echo "Location: $BFS_ROOT"
echo "Size: $(sudo du -sh $BFS_ROOT | cut -f1)"
echo ""
echo "Next step: Install kernel and bootloader"
