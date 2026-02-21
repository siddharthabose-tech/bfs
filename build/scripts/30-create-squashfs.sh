#!/bin/bash
# Create compressed squashfs filesystem

set -e

echo "================================"
echo "Creating Squashfs Filesystem"
echo "================================"
echo ""

BFS_ROOT="artifacts/bfs-root"
SQUASHFS_FILE="artifacts/filesystem.squashfs"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ ! -d "$BFS_ROOT" ]; then
    echo "Error: BFS root not found. Run previous scripts first."
    exit 1
fi

# Remove old squashfs if exists
if [ -f "$SQUASHFS_FILE" ]; then
    echo "Removing old squashfs..."
    rm -f "$SQUASHFS_FILE"
fi

echo -e "${BLUE}Compressing filesystem...${NC}"
echo "This will take 5-10 minutes"
echo ""
echo "Original size: $(sudo du -sh $BFS_ROOT | cut -f1)"
echo ""

# Create squashfs with good compression
# -comp xz: Use XZ compression (best ratio)
# -Xbcj x86: Optimize for x86 executables
# -b 1M: Use 1MB block size
sudo mksquashfs $BFS_ROOT $SQUASHFS_FILE \
    -comp xz \
    -Xbcj x86 \
    -b 1M \
    -noappend

echo ""
echo -e "${GREEN}✓ Squashfs created${NC}"
echo ""
echo "Original size:   $(sudo du -sh $BFS_ROOT | cut -f1)"
echo "Compressed size: $(du -sh $SQUASHFS_FILE | cut -f1)"
echo "Compression ratio: $(echo "scale=1; $(du -s $SQUASHFS_FILE | cut -f1) * 100 / $(sudo du -s $BFS_ROOT | cut -f1)" | bc)%"
echo ""
echo "File: $SQUASHFS_FILE"
