#!/bin/bash
# BFS Safe Mount Wrapper
# Prevents accidental mounts and provides clear feedback

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Log file
readonly LOG_FILE="/var/log/bfs/operations.log"
mkdir -p /var/log/bfs

#------------------------------------------------------------------------------
# Function: log_operation
# Description: Log all mount operations
#------------------------------------------------------------------------------
log_operation() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] MOUNT: $*" >> "$LOG_FILE"
}

#------------------------------------------------------------------------------
# Function: show_mount_info
# Description: Display what will be mounted before doing it
#------------------------------------------------------------------------------
show_mount_info() {
    local device="$1"
    local mountpoint="$2"
    local options="$3"
    
    echo ""
    echo "================================"
    echo "BFS Safe Mount"
    echo "================================"
    echo ""
    echo "Device:      $device"
    echo "Mount point: $mountpoint"
    echo "Options:     ${options:-defaults}"
    echo ""
    
    # Get device info
    local fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null || echo "unknown")
    local size=$(lsblk -n -o SIZE "$device" 2>/dev/null || echo "unknown")
    local label=$(blkid -o value -s LABEL "$device" 2>/dev/null || echo "none")
    
    echo "Filesystem:  $fs_type"
    echo "Size:        $size"
    echo "Label:       $label"
    echo ""
}

#------------------------------------------------------------------------------
# Function: confirm_mount
# Description: Ask user to confirm mount operation
#------------------------------------------------------------------------------
confirm_mount() {
    echo -e "${YELLOW}Proceed with mount? [y/N]${NC} "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Mount cancelled${NC}"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Function: safe_mount
# Description: Perform mount with safety checks
#------------------------------------------------------------------------------
safe_mount() {
    local device="$1"
    local mountpoint="$2"
    local options="$3"
    
    # Validate device exists
    if [ ! -b "$device" ]; then
        echo -e "${RED}Error: Device $device does not exist${NC}"
        return 1
    fi
    
    # Create mountpoint if it doesn't exist
    if [ ! -d "$mountpoint" ]; then
        echo "Creating mount point: $mountpoint"
        mkdir -p "$mountpoint"
    fi
    
    # Check if already mounted
    if mount | grep -q "$mountpoint"; then
        echo -e "${YELLOW}Warning: $mountpoint is already mounted${NC}"
        mount | grep "$mountpoint"
        return 1
    fi
    
    # Show info and get confirmation
    show_mount_info "$device" "$mountpoint" "$options"
    
    if ! confirm_mount; then
        return 1
    fi
    
    # Perform actual mount
    echo "Mounting..."
    if [ -n "$options" ]; then
        mount -o "$options" "$device" "$mountpoint"
    else
        mount "$device" "$mountpoint"
    fi
    
    # Verify mount succeeded
    if mount | grep -q "$mountpoint"; then
        echo -e "${GREEN}✓ Mount successful${NC}"
        log_operation "SUCCESS: Mounted $device to $mountpoint"
        
        # Show mount details
        echo ""
        mount | grep "$mountpoint"
        return 0
    else
        echo -e "${RED}✗ Mount failed${NC}"
        log_operation "FAILED: Could not mount $device to $mountpoint"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    if [ $# -lt 2 ]; then
        echo "Usage: bfs-mount <device> <mountpoint> [options]"
        echo ""
        echo "Example:"
        echo "  bfs-mount /dev/sda2 /mnt"
        echo "  bfs-mount /dev/sda2 /mnt ro,noexec"
        exit 1
    fi
    
    local device="$1"
    local mountpoint="$2"
    local options="$3"
    
    safe_mount "$device" "$mountpoint" "$options"
}

main "$@"
