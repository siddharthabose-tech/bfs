#!/bin/bash
# BFS Storage Stack Detection Orchestrator
# Coordinates LUKS unlock, LVM activation, and filesystem detection

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

# Detection directory
readonly DETECTION_DIR="/tmp/bfs-detection"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#------------------------------------------------------------------------------
# Function: run_storage_stack_detection
# Description: Complete storage stack detection workflow
#------------------------------------------------------------------------------
run_storage_stack_detection() {
    echo ""
    echo "========================================"
    echo "BFS Storage Stack Detection"
    echo "========================================"
    echo ""
    echo "This process will:"
    echo "1. Detect LUKS encrypted partitions"
    echo "2. Unlock encrypted volumes (with your passphrase)"
    echo "3. Detect and activate LVM volumes"
    echo "4. Prepare all storage for OS detection"
    echo ""
    
    # Phase 1: LUKS Detection
    echo -e "${BLUE}═══ Phase 1: LUKS Detection ═══${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/luks.sh" ]; then
        source "$SCRIPT_DIR/luks.sh"
        detect_luks_partitions
        
        # If LUKS devices found, offer to unlock
        if [ -s "$DETECTION_DIR/luks-devices.txt" ]; then
            echo ""
            echo "Encrypted partitions detected."
            echo ""
            read -p "Unlock encrypted partitions now? [Y/n] " -n 1 -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                unlock_all_luks_devices
            else
                echo "Skipping LUKS unlock. Encrypted partitions will not be accessible."
            fi
        fi
    else
        echo "LUKS module not found, skipping..."
    fi
    
    echo ""
    echo -e "${BLUE}═══ Phase 2: LVM Detection ═══${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/lvm.sh" ]; then
        source "$SCRIPT_DIR/lvm.sh"
        detect_lvm_volumes
        
        # If LVM found, activate
        if grep -q "Found" "$DETECTION_DIR/lvm-vgscan.txt" 2>/dev/null; then
            echo ""
            activate_lvm_volumes
            echo ""
            find_root_volumes
        fi
    else
        echo "LVM module not found, skipping..."
    fi
    
    echo ""
    echo -e "${BLUE}═══ Phase 3: Update Device List ═══${NC}"
    echo ""
    
    # Re-scan block devices now that LUKS/LVM are activated
    echo "Rescanning block devices..."
    blkid > "$DETECTION_DIR/blkid-post-storage.txt"
    lsblk > "$DETECTION_DIR/lsblk-post-storage.txt"
    
    # Update Linux candidates list to include newly accessible devices
    update_linux_candidates
    
    echo ""
    echo "========================================"
    echo "Storage Stack Detection Complete"
    echo "========================================"
    echo ""
    
    generate_storage_report
}

#------------------------------------------------------------------------------
# Function: update_linux_candidates
# Description: Update list of Linux candidates after storage activation
#------------------------------------------------------------------------------
update_linux_candidates() {
    local candidates=()
    
    # Find all Linux-like filesystems (including newly unlocked ones)
    while IFS= read -r line; do
        if [[ $line =~ (ext4|btrfs|xfs) ]]; then
            local device=$(echo "$line" | cut -d: -f1)
            candidates+=("$device")
        fi
    done < "$DETECTION_DIR/blkid-post-storage.txt"
    
    # Also include LVM root candidates
    if [ -f "$DETECTION_DIR/lvm-root-candidates.txt" ]; then
        while IFS= read -r device; do
            [ -n "$device" ] && candidates+=("$device")
        done < "$DETECTION_DIR/lvm-root-candidates.txt"
    fi
    
    # Remove duplicates and save
    printf '%s\n' "${candidates[@]}" | sort -u > "$DETECTION_DIR/linux-candidates-updated.txt"
    
    local count=$(wc -l < "$DETECTION_DIR/linux-candidates-updated.txt")
    echo -e "${GREEN}✓ Updated Linux candidates: $count device(s)${NC}"
}

#------------------------------------------------------------------------------
# Function: generate_storage_report
# Description: Create comprehensive storage stack report
#------------------------------------------------------------------------------
generate_storage_report() {
    local report="$DETECTION_DIR/storage-stack-report.txt"
    
    cat > "$report" << REPORT
BFS Storage Stack Detection Report
Generated: $(date)
========================================

LUKS ENCRYPTION
---------------
REPORT
    
    if [ -s "$DETECTION_DIR/luks-devices.txt" ]; then
        cat "$DETECTION_DIR/luks-devices.txt" >> "$report"
        
        if [ -f "$DETECTION_DIR/luks-unlocked.txt" ]; then
            echo "" >> "$report"
            echo "Unlocked:" >> "$report"
            cat "$DETECTION_DIR/luks-unlocked.txt" >> "$report"
        fi
    else
        echo "No LUKS encrypted partitions detected" >> "$report"
    fi
    
    cat >> "$report" << REPORT

LVM VOLUMES
-----------
REPORT
    
    if [ -f "$DETECTION_DIR/lvm-vgdisplay.txt" ] && [ -s "$DETECTION_DIR/lvm-vgdisplay.txt" ]; then
        grep -A 10 "VG Name" "$DETECTION_DIR/lvm-vgdisplay.txt" >> "$report" || echo "None" >> "$report"
    else
        echo "No LVM volumes detected" >> "$report"
    fi
    
    cat >> "$report" << REPORT

ACCESSIBLE DEVICES (Post-Storage-Stack)
----------------------------------------
REPORT
    
    cat "$DETECTION_DIR/lsblk-post-storage.txt" >> "$report"
    
    cat >> "$report" << REPORT

LINUX CANDIDATES (Updated)
---------------------------
REPORT
    
    cat "$DETECTION_DIR/linux-candidates-updated.txt" >> "$report"
    
    echo ""
    echo -e "${GREEN}✓ Storage report saved: $report${NC}"
    echo ""
    echo "Next step: Run OS detection on accessible devices"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    run_storage_stack_detection
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
