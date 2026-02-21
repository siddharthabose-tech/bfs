#!/bin/bash
# Install Linux kernel and boot tools

set -e

echo "================================"
echo "Installing Kernel & Boot Tools"
echo "================================"
echo ""

BFS_ROOT="artifacts/bfs-root"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -d "$BFS_ROOT" ]; then
    echo "Error: BFS root not found. Run 10-bootstrap-bfs.sh first."
    exit 1
fi

echo -e "${BLUE}Stage 1: Mount necessary filesystems${NC}"

# Mount proc, sys, dev for chroot
sudo mount -t proc none $BFS_ROOT/proc
sudo mount -t sysfs none $BFS_ROOT/sys
sudo mount -o bind /dev $BFS_ROOT/dev
sudo mount -o bind /dev/pts $BFS_ROOT/dev/pts

# Function to cleanup mounts on exit
cleanup() {
    echo ""
    echo "Cleaning up mounts..."
    sudo umount $BFS_ROOT/dev/pts 2>/dev/null || true
    sudo umount $BFS_ROOT/dev 2>/dev/null || true
    sudo umount $BFS_ROOT/sys 2>/dev/null || true
    sudo umount $BFS_ROOT/proc 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${GREEN}✓ Filesystems mounted${NC}"
echo ""

echo -e "${BLUE}Stage 2: Install kernel and boot tools${NC}"

# Update package lists
sudo chroot $BFS_ROOT apt update

# Install kernel and essential boot tools
sudo chroot $BFS_ROOT apt install -y \
    linux-image-amd64 \
    live-boot \
    systemd-sysv

echo -e "${GREEN}✓ Kernel installed${NC}"
echo ""

echo -e "${BLUE}Stage 3: Install boot loader tools${NC}"

# Install GRUB (we'll configure it later)
sudo chroot $BFS_ROOT apt install -y \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    grub2-common

echo -e "${GREEN}✓ GRUB tools installed${NC}"
echo ""

# Check what kernel was installed
echo "Installed kernel:"
ls -lh $BFS_ROOT/boot/vmlinuz-*

echo ""
echo "================================"
echo "Kernel Installation Complete"
echo "================================"
echo ""
echo "Kernel: $(ls $BFS_ROOT/boot/vmlinuz-* | head -1 | xargs basename)"
echo "Initramfs: $(ls $BFS_ROOT/boot/initrd.img-* | head -1 | xargs basename)"
echo "Size: $(sudo du -sh $BFS_ROOT | cut -f1)"
echo ""
echo "Next step: Create bootable ISO"
