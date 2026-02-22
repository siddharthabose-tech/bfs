#!/bin/bash
# BFS LVM Detection and Activation Module

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
# Function: detect_lvm_volumes
# Description: Find LVM physical volumes, volume groups, and logical volumes
#------------------------------------------------------------------------------
detect_lvm_volumes() {
    echo -e "${BLUE}[LVM] Scanning for LVM volumes...${NC}"
    
    # Check if LVM tools are available
    if ! command -v vgscan >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ LVM tools not available${NC}"
        return 1
    fi
    
    # Scan for volume groups
    vgscan > "$DETECTION_DIR/lvm-vgscan.txt" 2>&1
    
    # Get detailed info
    pvdisplay > "$DETECTION_DIR/lvm-pvdisplay.txt" 2>&1 || true
    vgdisplay > "$DETECTION_DIR/lvm-vgdisplay.txt" 2>&1 || true
    lvdisplay > "$DETECTION_DIR/lvm-lvdisplay.txt" 2>&1 || true
    
    # Count volume groups
    local vg_count=$(vgs --noheadings 2>/dev/null | wc -l)
    local lv_count=$(lvs --noheadings 2>/dev/null | wc -l)
    
    if [ $vg_count -eq 0 ]; then
        echo -e "${GREEN}✓ No LVM volumes found${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}✓ Found $vg_count volume group(s), $lv_count logical volume(s)${NC}"
    
    # List volume groups
    vgs --noheadings -o vg_name,vg_size,vg_free 2>/dev/null | while read -r vg size free; do
        echo "  VG: $vg (Size: $size, Free: $free)"
        
        # List logical volumes in this VG
        lvs --noheadings -o lv_name,lv_size $vg 2>/dev/null | while read -r lv lv_size; do
            echo "    LV: $lv ($lv_size)"
        done
    done
    
    return 0
}

#------------------------------------------------------------------------------
# Function: activate_lvm_volumes
# Description: Activate all LVM volume groups
#------------------------------------------------------------------------------
activate_lvm_volumes() {
    echo -e "${BLUE}[LVM] Activating volume groups...${NC}"
    
    # Activate all volume groups
    if vgchange -ay > "$DETECTION_DIR/lvm-activation.txt" 2>&1; then
        echo -e "${GREEN}✓ LVM volumes activated${NC}"
        
        # List activated volumes
        lvs --noheadings -o vg_name,lv_name,lv_path 2>/dev/null | while read -r vg lv path; do
            echo "  Activated: $path ($vg/$lv)"
        done
        
        return 0
    else
        echo -e "${YELLOW}⚠ LVM activation had issues (see log)${NC}"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Function: find_root_volumes
# Description: Identify which LVM volumes might contain root filesystems
#------------------------------------------------------------------------------
find_root_volumes() {
    echo -e "${BLUE}[LVM] Identifying potential root volumes...${NC}"
    
    local root_candidates=()
    
    # Look for common root volume names
    while IFS= read -r path; do
        if [[ $path =~ (root|ubuntu|debian|fedora|arch) ]]; then
            root_candidates+=("$path")
        fi
    done < <(lvs --noheadings -o lv_path 2>/dev/null)
    
    # Save results
    printf '%s\n' "${root_candidates[@]}" > "$DETECTION_DIR/lvm-root-candidates.txt"
    
    local count=${#root_candidates[@]}
    
    if [ $count -eq 0 ]; then
        echo "  No obvious root volumes found"
        echo "  Will check all logical volumes during OS detection"
        return 0
    fi
    
    echo -e "${GREEN}✓ Found $count potential root volume(s)${NC}"
    for vol in "${root_candidates[@]}"; do
        local fs=$(blkid -s TYPE -o value "$vol" 2>/dev/null || echo "unknown")
        echo "  - $vol ($fs)"
    done
    
    return 0
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    echo ""
    echo "================================"
    echo "BFS LVM Detection"
    echo "================================"
    echo ""
    
    detect_lvm_volumes
    
    if [ -s "$DETECTION_DIR/lvm-vgdisplay.txt" ]; then
        echo ""
        activate_lvm_volumes
        echo ""
        find_root_volumes
    fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
