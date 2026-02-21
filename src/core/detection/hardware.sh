#!/bin/bash
# BFS Hardware Detection Module
# Detects all storage devices and partitions

# Color codes
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Output directory for detection results
readonly DETECTION_DIR="/tmp/bfs-detection"
mkdir -p "$DETECTION_DIR"

#------------------------------------------------------------------------------
# Function: detect_block_devices
# Description: Find all block devices (disks and partitions)
#------------------------------------------------------------------------------
detect_block_devices() {
    echo -e "${BLUE}[Detection] Scanning block devices...${NC}"
    
    # Use lsblk to get detailed info in JSON format
    lsblk -J -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID,LABEL > "$DETECTION_DIR/lsblk.json"
    
    # Also get human-readable output
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID,LABEL > "$DETECTION_DIR/lsblk.txt"
    
    # Count devices
    local disk_count=$(lsblk -d -n -o TYPE | grep -c disk)
    local part_count=$(lsblk -n -o TYPE | grep -c part)
    
    echo -e "${GREEN}✓ Found $disk_count disks, $part_count partitions${NC}"
    
    return 0
}

#------------------------------------------------------------------------------
# Function: detect_filesystems
# Description: Identify filesystem types on all partitions
#------------------------------------------------------------------------------
detect_filesystems() {
    echo -e "${BLUE}[Detection] Analyzing filesystems...${NC}"
    
    # Use blkid to get detailed filesystem info
    blkid > "$DETECTION_DIR/blkid.txt"
    
    # Create structured data
    blkid -o export | awk 'BEGIN {RS=""} {print}' > "$DETECTION_DIR/blkid-export.txt"
    
    # Count different filesystem types
    local ext4_count=$(blkid | grep -c ext4)
    local btrfs_count=$(blkid | grep -c btrfs)
    local ntfs_count=$(blkid | grep -c ntfs)
    local luks_count=$(blkid | grep -c crypto_LUKS)
    
    echo -e "${GREEN}✓ Filesystem summary:${NC}"
    [ $ext4_count -gt 0 ] && echo "  - ext4: $ext4_count"
    [ $btrfs_count -gt 0 ] && echo "  - btrfs: $btrfs_count"
    [ $ntfs_count -gt 0 ] && echo "  - ntfs: $ntfs_count (Windows)"
    [ $luks_count -gt 0 ] && echo "  - LUKS encrypted: $luks_count"
    
    return 0
}

#------------------------------------------------------------------------------
# Function: identify_potential_linux_partitions
# Description: Find partitions that might contain Linux
#------------------------------------------------------------------------------
identify_potential_linux_partitions() {
    echo -e "${BLUE}[Detection] Identifying potential Linux partitions...${NC}"
    
    # Linux typically uses ext4, btrfs, or xfs
    # Also check for encrypted (LUKS) partitions
    
    local linux_parts=()
    
    # Get all ext4/btrfs/xfs partitions
    while IFS= read -r line; do
        if [[ $line =~ (ext4|btrfs|xfs|crypto_LUKS) ]]; then
            device=$(echo "$line" | cut -d: -f1)
            linux_parts+=("$device")
        fi
    done < "$DETECTION_DIR/blkid.txt"
    
    # Save results
    printf '%s\n' "${linux_parts[@]}" > "$DETECTION_DIR/linux-candidates.txt"
    
    local count=${#linux_parts[@]}
    echo -e "${GREEN}✓ Found $count potential Linux partitions${NC}"
    
    # Display them
    if [ $count -gt 0 ]; then
        echo "Candidates:"
        for part in "${linux_parts[@]}"; do
            local fs=$(blkid -o value -s TYPE "$part" 2>/dev/null || echo "unknown")
            local size=$(lsblk -n -o SIZE "$part" 2>/dev/null || echo "unknown")
            echo "  - $part ($fs, $size)"
        done
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Function: check_for_efi
# Description: Detect if system uses UEFI or BIOS
#------------------------------------------------------------------------------
check_for_efi() {
    echo -e "${BLUE}[Detection] Checking boot mode (UEFI vs BIOS)...${NC}"
    
    local boot_mode="UNKNOWN"
    
    # Check if EFI directory exists
    if [ -d /sys/firmware/efi ]; then
        boot_mode="UEFI"
        echo -e "${GREEN}✓ System is UEFI${NC}"
        
        # Find EFI System Partition (ESP)
        local esp=$(blkid | grep -i "PARTLABEL=\"EFI" | cut -d: -f1)
        if [ -z "$esp" ]; then
            esp=$(blkid -t TYPE=vfat | grep -E "/dev/[a-z]+[0-9]+1:" | cut -d: -f1)
        fi
        
        if [ -n "$esp" ]; then
            echo "  EFI System Partition: $esp"
            echo "$esp" > "$DETECTION_DIR/esp.txt"
        fi
    else
        boot_mode="BIOS"
        echo -e "${GREEN}✓ System is BIOS (Legacy)${NC}"
    fi
    
    echo "$boot_mode" > "$DETECTION_DIR/boot-mode.txt"
    
    return 0
}

#------------------------------------------------------------------------------
# Function: generate_hardware_report
# Description: Create summary report of hardware detection
#------------------------------------------------------------------------------
generate_hardware_report() {
    local report="$DETECTION_DIR/hardware-report.txt"
    
    cat > "$report" << REPORT
BFS Hardware Detection Report
Generated: $(date)
========================================

BOOT MODE
---------
$(cat "$DETECTION_DIR/boot-mode.txt" 2>/dev/null || echo "UNKNOWN")

BLOCK DEVICES
-------------
$(cat "$DETECTION_DIR/lsblk.txt")

LINUX CANDIDATES
----------------
$(cat "$DETECTION_DIR/linux-candidates.txt" 2>/dev/null || echo "None found")

FILESYSTEM DETAILS
------------------
$(cat "$DETECTION_DIR/blkid.txt")

REPORT
    
    echo -e "${GREEN}✓ Hardware report saved to: $report${NC}"
}

#------------------------------------------------------------------------------
# Main execution
#------------------------------------------------------------------------------
main() {
    echo ""
    echo "================================"
    echo "BFS Hardware Detection"
    echo "================================"
    echo ""
    
    # Run all detection functions
    detect_block_devices
    echo ""
    
    detect_filesystems
    echo ""
    
    identify_potential_linux_partitions
    echo ""
    
    check_for_efi
    echo ""
    
    generate_hardware_report
    
    echo ""
    echo "================================"
    echo "Hardware Detection Complete"
    echo "================================"
    echo ""
    echo "Detection data saved to: $DETECTION_DIR"
    echo ""
    echo "Next step: OS Detection"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
