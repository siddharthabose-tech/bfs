#!/bin/bash
# Test creating a minimal Debian base

set -e

echo "================================"
echo "Testing Debian Bootstrap"
echo "================================"
echo ""

# Create artifacts directory if it doesn't exist
mkdir -p artifacts/test-bootstrap

# Remove old test if exists
if [ -d "artifacts/test-bootstrap/rootfs" ]; then
    echo "Removing old test..."
    sudo rm -rf artifacts/test-bootstrap/rootfs
fi

echo "Creating minimal Debian bookworm base..."
echo "This will take 5-10 minutes and download ~150MB"
echo ""

# Run debootstrap
sudo debootstrap \
    --variant=minbase \
    --include=systemd,udev \
    bookworm \
    artifacts/test-bootstrap/rootfs \
    http://deb.debian.org/debian/

echo ""
echo "✓ Bootstrap complete!"
echo ""
echo "Testing the created system..."

# Check some basic things
sudo ls -la artifacts/test-bootstrap/rootfs/

echo ""
echo "Checking installed packages..."
sudo chroot artifacts/test-bootstrap/rootfs dpkg -l | head -20

echo ""
echo "Size of created system:"
sudo du -sh artifacts/test-bootstrap/rootfs

echo ""
echo "================================"
echo "✓ Debian bootstrap test PASSED!"
echo "================================"
echo ""
echo "The minimal Debian system is in:"
echo "  artifacts/test-bootstrap/rootfs/"
