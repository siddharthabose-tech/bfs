#!/bin/bash
# Build bootable ISO image

set -e

echo "================================"
echo "Building Bootable ISO"
echo "================================"
echo ""

ISO_DIR="artifacts/iso"
ISO_FILE="artifacts/bfs-v0.1-test.iso"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -d "$ISO_DIR" ]; then
    echo "Error: ISO directory not found. Run 40-prepare-iso.sh first."
    exit 1
fi

# Remove old ISO if exists
if [ -f "$ISO_FILE" ]; then
    echo "Removing old ISO..."
    rm -f "$ISO_FILE"
fi

echo -e "${BLUE}Creating bootable ISO...${NC}"
echo "This will take 2-3 minutes"
echo ""

# Create ISO with GRUB bootloader
# -r: Rock Ridge extensions (long filenames)
# -J: Joliet extensions (Windows compatibility)
# -o: Output file
# -b: Boot image
# -c: Boot catalog
# --no-emul-boot: Don't emulate floppy
# --boot-load-size 4: Load 4 sectors
# --boot-info-table: Create boot info table

grub-mkrescue -o $ISO_FILE $ISO_DIR

echo ""
echo -e "${GREEN}✓ ISO created successfully!${NC}"
echo ""
echo "================================"
echo "BFS ISO Information"
echo "================================"
echo ""
echo "File: $ISO_FILE"
echo "Size: $(du -h $ISO_FILE | cut -f1)"
echo ""
echo "This ISO is bootable and can be:"
echo "  - Written to USB drive"
echo "  - Booted in QEMU (virtual machine)"
echo "  - Burned to DVD"
echo ""
echo "Next step: Test in QEMU"
