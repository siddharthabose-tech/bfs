#!/bin/bash
# Test BFS ISO in QEMU virtual machine

set -e

ISO_FILE="artifacts/bfs-v0.1-test.iso"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ ! -f "$ISO_FILE" ]; then
    echo "Error: ISO not found. Run 50-build-iso.sh first."
    exit 1
fi

echo "================================"
echo "Testing BFS in QEMU"
echo "================================"
echo ""
echo -e "${BLUE}Starting QEMU...${NC}"
echo ""
echo "You should see:"
echo "  1. GRUB boot menu"
echo "  2. BFS booting"
echo "  3. Login prompt"
echo ""
echo "Login with:"
echo "  Username: root"
echo "  Password: bfs"
echo ""
echo -e "${YELLOW}To exit QEMU: Press Ctrl+A then X${NC}"
echo ""
echo "Press Enter to start..."
read

# Start QEMU with the ISO
# -m 2G: 2GB RAM
# -cdrom: Boot from ISO
# -boot d: Boot from CD-ROM
# -enable-kvm: Use hardware acceleration (if available)
qemu-system-x86_64 \
    -m 2G \
    -cdrom $ISO_FILE \
    -boot d \
    -enable-kvm 2>/dev/null || qemu-system-x86_64 \
    -m 2G \
    -cdrom $ISO_FILE \
    -boot d

echo ""
echo "QEMU closed."
