#!/bin/bash
# BFS LUKS Detection and Unlock Module

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Detection directory
readonly DETECTION_DIR="/tmp/bfs-detection"
mkdir -p "$DETECTION_DIR"

#------------------------------------------------------------------------------
# Function: detect_luks_partitions
# Description: Find all LUKS encrypted partitions
#------------------------------------------------------------------------------
detect_luks_partitions() {
    echo -e "${BLUE}[LUKS] Scanning for encrypted partitions...${NC}"
    
    local luks_devices=()
    
    # Find all LUKS partitions
    while IFS= read -r line; do
        if [[ $line =~ crypto_LUKS ]]; then
            local device=$(echo "$line" | cut -d: -f1)
            luks_devices+=("$device")
        fi
    done < <(blkid)
    
    # Save results
    printf '%s\n' "${luks_devices[@]}" > "$DETECTION_DIR/luks-devices.txt"
    
    local count=${#luks_devices[@]}
    
    if [ $count -eq 0 ]; then
        echo -e "${GREEN}✓ No encrypted partitions found${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}✓ Found $count encrypted partition(s)${NC}"
    
    for device in "${luks_devices[@]}"; do
        local size=$(lsblk -n -o SIZE "$device" 2>/dev/null || echo "unknown")
        local uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || echo "none")
        echo "  - $device ($size) UUID: $uuid"
    done
    
    return 0
}

#------------------------------------------------------------------------------
# Function: get_luks_info
# Description: Get detailed info about a LUKS device
#------------------------------------------------------------------------------
get_luks_info() {
    local device="$1"
    
    echo ""
    echo "LUKS Device Information"
    echo "======================="
    echo "Device: $device"
    echo ""
    
    # Get LUKS version and cipher info
    if command -v cryptsetup >/dev/null 2>&1; then
        cryptsetup luksDump "$device" 2>/dev/null | head -20
    else
        echo "Note: cryptsetup not available for detailed info"
    fi
}

#------------------------------------------------------------------------------
# Function: check_if_unlocked
# Description: Check if LUKS device is already unlocked
#------------------------------------------------------------------------------
check_if_unlocked() {
    local device="$1"
    
    # Get UUID
    local uuid=$(blkid -s UUID -o value "$device" 2>/dev/null)
    
    # Check if mapper device exists
    if [ -n "$uuid" ] && [ -e "/dev/mapper/luks-$uuid" ]; then
        echo "/dev/mapper/luks-$uuid"
        return 0
    fi
    
    # Check for any mapper device pointing to this device
    for mapper in /dev/mapper/*; do
        if cryptsetup status "$mapper" 2>/dev/null | grep -q "$device"; then
            echo "$mapper"
            return 0
        fi
    done
    
    return 1
}

#------------------------------------------------------------------------------
# Function: unlock_luks_device
# Description: Unlock a LUKS encrypted partition with user-provided passphrase
#------------------------------------------------------------------------------
unlock_luks_device() {
    local device="$1"
    local mapper_name="${2:-luks-$(blkid -s UUID -o value $device)}"
    
    echo ""
    echo "================================"
    echo "LUKS Encryption Unlock"
    echo "================================"
    echo ""
    echo "Device:    $device"
    echo "Size:      $(lsblk -n -o SIZE $device)"
    echo ""
    
    # Check if already unlocked
    local existing_mapper
    if existing_mapper=$(check_if_unlocked "$device"); then
        echo -e "${GREEN}✓ Already unlocked: $existing_mapper${NC}"
        echo "$existing_mapper" > "$DETECTION_DIR/unlocked-$device.txt"
        return 0
    fi
    
    echo -e "${YELLOW}This partition is encrypted.${NC}"
    echo ""
    echo "To identify your Linux system, we need to unlock it first."
    echo "Without the passphrase, we cannot access this partition."
    echo "This is by design - encryption protects your data."
    echo ""
    
    # Attempt unlock (up to 3 tries)
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        echo -e "${BLUE}Attempt $attempts of $max_attempts${NC}"
        echo -n "Enter passphrase: "
        
        # Use cryptsetup luksOpen
        if cryptsetup luksOpen "$device" "$mapper_name"; then
            echo ""
            echo -e "${GREEN}✓ Successfully unlocked!${NC}"
            echo "Mapped to: /dev/mapper/$mapper_name"
            
            # Save unlock info
            echo "/dev/mapper/$mapper_name" > "$DETECTION_DIR/unlocked-$device.txt"
            
            # Add to list of unlocked devices
            echo "$device → /dev/mapper/$mapper_name" >> "$DETECTION_DIR/luks-unlocked.txt"
            
            return 0
        else
            echo -e "${RED}✗ Incorrect passphrase${NC}"
            echo ""
        fi
    done
    
    # Failed after 3 attempts
    echo ""
    echo -e "${YELLOW}⚠ Could not unlock after $max_attempts attempts${NC}"
    echo ""
    echo "Options:"
    echo "1. Skip this partition (may find other Linux installs)"
    echo "2. Data rescue mode (backup LUKS header)"
    echo "3. Continue without unlocking"
    echo ""
    
    return 1
}

#------------------------------------------------------------------------------
# Function: unlock_all_luks_devices
# Description: Attempt to unlock all LUKS devices found
#------------------------------------------------------------------------------
unlock_all_luks_devices() {
    local luks_file="$DETECTION_DIR/luks-devices.txt"
    
    if [ ! -f "$luks_file" ] || [ ! -s "$luks_file" ]; then
        echo "No LUKS devices to unlock"
        return 0
    fi
    
    echo ""
    echo "================================"
    echo "LUKS Unlock Wizard"
    echo "================================"
    echo ""
    
    local count=0
    local unlocked=0
    
    while IFS= read -r device; do
        [ -z "$device" ] && continue
        count=$((count + 1))
        
        if unlock_luks_device "$device"; then
            unlocked=$((unlocked + 1))
        fi
        
        echo ""
    done < "$luks_file"
    
    echo "================================"
    echo "LUKS Unlock Summary"
    echo "================================"
    echo "Total encrypted: $count"
    echo "Successfully unlocked: $unlocked"
    echo ""
    
    if [ $unlocked -gt 0 ]; then
        echo "Unlocked devices are now accessible for OS detection."
    fi
}

#------------------------------------------------------------------------------
# Function: luks_graceful_degradation
# Description: Handle case where user forgot passphrase
#------------------------------------------------------------------------------
luks_graceful_degradation() {
    local device="$1"
    
    echo ""
    echo "================================"
    echo "LUKS Recovery Options"
    echo "================================"
    echo ""
    echo "We cannot unlock the encrypted partition."
    echo ""
    echo "However, we can still help you:"
    echo ""
    echo "1. Backup LUKS Header"
    echo "   Save encryption metadata for future recovery"
    echo "   Command: cryptsetup luksHeaderBackup"
    echo ""
    echo "2. Search for other Linux installations"
    echo "   Skip this partition and check others"
    echo ""
    echo "3. Learn about LUKS password recovery"
    echo "   Browse offline documentation"
    echo ""
    echo "4. Generate diagnostic report"
    echo "   Create report for data recovery specialist"
    echo ""
    
    # For now, just inform user
    echo "Note: LUKS password recovery is typically impossible without the passphrase."
    echo "This is intentional - it's what makes encryption secure."
    echo ""
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    echo ""
    echo "================================"
    echo "BFS LUKS Detection"
    echo "================================"
    echo ""
    
    detect_luks_partitions
    
    if [ -s "$DETECTION_DIR/luks-devices.txt" ]; then
        echo ""
        read -p "Would you like to unlock encrypted partitions? [Y/n] " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            unlock_all_luks_devices
        fi
    fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
