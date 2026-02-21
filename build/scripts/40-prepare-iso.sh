#!/bin/bash
# Prepare ISO directory structure

set -e

echo "================================"
echo "Preparing ISO Structure"
echo "================================"
echo ""

ISO_DIR="artifacts/iso"
SQUASHFS_FILE="artifacts/filesystem.squashfs"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check squashfs exists
if [ ! -f "$SQUASHFS_FILE" ]; then
    echo "Error: Squashfs not found. Run 30-create-squashfs.sh first."
    exit 1
fi

# Clean and create ISO directory
echo -e "${BLUE}Creating ISO directory structure...${NC}"
rm -rf $ISO_DIR
mkdir -p $ISO_DIR/{live,boot/grub,isolinux}

# Copy kernel and initrd from BFS root
echo "Copying kernel and initramfs..."
KERNEL=$(ls artifacts/bfs-root/boot/vmlinuz-* | head -1)
INITRD=$(ls artifacts/bfs-root/boot/initrd.img-* | head -1)

cp $KERNEL $ISO_DIR/live/vmlinuz
cp $INITRD $ISO_DIR/live/initrd.img

echo -e "${GREEN}✓ Kernel copied${NC}"

# Copy squashfs
echo "Copying squashfs filesystem..."
cp $SQUASHFS_FILE $ISO_DIR/live/filesystem.squashfs

echo -e "${GREEN}✓ Squashfs copied${NC}"

# Create minimal GRUB config
echo "Creating GRUB configuration..."
cat > $ISO_DIR/boot/grub/grub.cfg << 'GRUBCFG'
set timeout=5
set default=0

menuentry "BFS - Bootable Fix System" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}

menuentry "BFS - Debug Mode (verbose)" {
    linux /live/vmlinuz boot=live debug
    initrd /live/initrd.img
}
GRUBCFG

echo -e "${GREEN}✓ GRUB configured${NC}"

# Show ISO structure
echo ""
echo "================================"
echo "ISO Structure Ready"
echo "================================"
echo ""
tree -h -L 3 $ISO_DIR
echo ""
echo "Total ISO contents: $(du -sh $ISO_DIR | cut -f1)"
