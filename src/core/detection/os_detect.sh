#!/bin/bash
# BFS OS Detection Module
# Identifies Linux distributions on mounted filesystems

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Detection output directory
readonly DETECTION_DIR="/tmp/bfs-detection"
mkdir -p "$DETECTION_DIR"

#------------------------------------------------------------------------------
# Function: parse_os_release
# Description: Parse /etc/os-release file and extract key information
# Arguments: $1 - Path to os-release file
#------------------------------------------------------------------------------
parse_os_release() {
    local os_release_file="$1"
    local output_file="$DETECTION_DIR/os-release-parsed.txt"
    
    if [ ! -f "$os_release_file" ]; then
        echo "ERROR: os-release file not found: $os_release_file"
        return 1
    fi
    
    # Parse key fields
    local name=$(grep ^NAME= "$os_release_file" | cut -d'"' -f2)
    local version=$(grep ^VERSION= "$os_release_file" | cut -d'"' -f2)
    local id=$(grep ^ID= "$os_release_file" | cut -d= -f2 | tr -d '"')
    local id_like=$(grep ^ID_LIKE= "$os_release_file" | cut -d= -f2 | tr -d '"')
    local version_id=$(grep ^VERSION_ID= "$os_release_file" | cut -d= -f2 | tr -d '"')
    local pretty_name=$(grep ^PRETTY_NAME= "$os_release_file" | cut -d'"' -f2)
    
    # Create structured output
    cat > "$output_file" << PARSED
NAME=$name
VERSION=$version
ID=$id
ID_LIKE=$id_like
VERSION_ID=$version_id
PRETTY_NAME=$pretty_name
PARSED
    
    echo "$output_file"
    return 0
}

#------------------------------------------------------------------------------
# Function: identify_distro_family
# Description: Determine distribution family (debian, arch, fedora, etc.)
#------------------------------------------------------------------------------
identify_distro_family() {
    local id="$1"
    local id_like="$2"
    
    # Check ID_LIKE first (more specific)
    if [[ "$id_like" =~ debian|ubuntu ]]; then
        echo "debian"
    elif [[ "$id_like" =~ fedora|rhel ]]; then
        echo "fedora"
    elif [[ "$id_like" =~ arch ]]; then
        echo "arch"
    elif [[ "$id_like" =~ suse ]]; then
        echo "suse"
    # Fall back to ID
    elif [[ "$id" == "debian" ]]; then
        echo "debian"
    elif [[ "$id" == "ubuntu" ]]; then
        echo "debian"
    elif [[ "$id" == "fedora" ]]; then
        echo "fedora"
    elif [[ "$id" == "arch" ]]; then
        echo "arch"
    elif [[ "$id" =~ mint|pop|elementary|zorin ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

#------------------------------------------------------------------------------
# Function: calculate_confidence
# Description: Calculate confidence score for OS detection
# Returns: 0-100 score
#------------------------------------------------------------------------------
calculate_confidence() {
    local os_release_exists="$1"
    local has_name="$2"
    local has_id="$3"
    local has_version="$4"
    
    local confidence=0
    
    # os-release exists: +40 points
    [ "$os_release_exists" = "true" ] && confidence=$((confidence + 40))
    
    # Has NAME field: +20 points
    [ -n "$has_name" ] && confidence=$((confidence + 20))
    
    # Has ID field: +25 points
    [ -n "$has_id" ] && confidence=$((confidence + 25))
    
    # Has VERSION_ID: +15 points
    [ -n "$has_version" ] && confidence=$((confidence + 15))
    
    echo "$confidence"
}

#------------------------------------------------------------------------------
# Function: detect_from_fingerprints
# Description: Fallback detection using filesystem fingerprints
#------------------------------------------------------------------------------
detect_from_fingerprints() {
    local mount_point="$1"
    
    echo -e "${YELLOW}[Detection] Using fingerprint detection (fallback)...${NC}"
    
    local fingerprints=""
    
    # Check for distro-specific files/directories
    [ -f "$mount_point/etc/lsb-release" ] && fingerprints="$fingerprints ubuntu/mint/debian-based"
    [ -d "$mount_point/snap" ] && fingerprints="$fingerprints ubuntu"
    [ -f "$mount_point/etc/arch-release" ] && fingerprints="$fingerprints arch"
    [ -f "$mount_point/etc/fedora-release" ] && fingerprints="$fingerprints fedora"
    [ -f "$mount_point/etc/debian_version" ] && fingerprints="$fingerprints debian"
    [ -d "$mount_point/etc/pacman.d" ] && fingerprints="$fingerprints arch"
    
    if [ -n "$fingerprints" ]; then
        echo "  Fingerprints found: $fingerprints"
        echo "$fingerprints" > "$DETECTION_DIR/fingerprints.txt"
        return 0
    else
        echo "  No recognizable fingerprints found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Function: detect_os_on_partition
# Description: Main OS detection function for a mounted partition
# Arguments: $1 - Device (e.g., /dev/sda2)
#            $2 - Mount point (e.g., /mnt/test)
#------------------------------------------------------------------------------
detect_os_on_partition() {
    local device="$1"
    local mount_point="$2"
    
    echo ""
    echo "================================"
    echo "OS Detection: $device"
    echo "================================"
    echo ""
    
    # Check if mounted
    if ! mount | grep -q "$mount_point"; then
        echo -e "${RED}Error: $mount_point is not mounted${NC}"
        return 1
    fi
    
    # Check for /etc/os-release
    local os_release="$mount_point/etc/os-release"
    
    if [ -f "$os_release" ]; then
        echo -e "${GREEN}✓ Found /etc/os-release${NC}"
        
        # Parse it
        local parsed=$(parse_os_release "$os_release")
        
        # Extract values
        source "$parsed"
        
        # Identify family
        local family=$(identify_distro_family "$ID" "$ID_LIKE")
        
        # Calculate confidence
        local confidence=$(calculate_confidence "true" "$NAME" "$ID" "$VERSION_ID")
        
        # Display results
        echo ""
        echo "Detection Results:"
        echo "  Name:       $PRETTY_NAME"
        echo "  ID:         $ID"
        echo "  Version:    $VERSION_ID"
        echo "  Family:     $family"
        echo "  Confidence: $confidence%"
        
        # Save structured results
        cat > "$DETECTION_DIR/os-detection-$device.json" << JSON
{
  "device": "$device",
  "name": "$NAME",
  "pretty_name": "$PRETTY_NAME",
  "id": "$ID",
  "id_like": "$ID_LIKE",
  "version": "$VERSION",
  "version_id": "$VERSION_ID",
  "family": "$family",
  "confidence": $confidence,
  "method": "os-release"
}
JSON
        
        echo ""
        echo -e "${GREEN}✓ Detection complete (confidence: $confidence%)${NC}"
        
    else
        echo -e "${YELLOW}⚠ /etc/os-release not found${NC}"
        
        # Try fingerprint detection
        if detect_from_fingerprints "$mount_point"; then
            local confidence=30
            echo ""
            echo "Detection Results:"
            echo "  Method:     Fingerprint-based"
            echo "  Confidence: $confidence% (low - fingerprints only)"
        else
            echo -e "${RED}✗ Could not identify OS${NC}"
            return 1
        fi
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Function: detect_all_linux_systems
# Description: Detect OS on all potential Linux partitions
#------------------------------------------------------------------------------
detect_all_linux_systems() {
    echo ""
    echo "================================"
    echo "BFS OS Detection (All Systems)"
    echo "================================"
    echo ""
    
    # Read Linux candidates from hardware detection
    local candidates_file="$DETECTION_DIR/linux-candidates.txt"
    
    if [ ! -f "$candidates_file" ]; then
        echo -e "${RED}Error: No Linux candidates found${NC}"
        echo "Run hardware detection first: src/core/detection/hardware.sh"
        return 1
    fi
    
    local count=0
    local detected=0
    
    # Create temporary mount point
    local temp_mount="/mnt/bfs-detect-$$"
    mkdir -p "$temp_mount"
    
    while IFS= read -r device; do
        [ -z "$device" ] && continue
        count=$((count + 1))
        
        echo -e "${BLUE}[Checking $device]${NC}"
        
        # Try to mount read-only
        if mount -o ro "$device" "$temp_mount" 2>/dev/null; then
            # Detect OS
            if detect_os_on_partition "$device" "$temp_mount"; then
                detected=$((detected + 1))
            fi
            
            # Unmount
            umount "$temp_mount"
        else
            echo -e "${YELLOW}⚠ Could not mount $device${NC}"
        fi
        
        echo ""
    done < "$candidates_file"
    
    # Cleanup
    rmdir "$temp_mount"
    
    echo "================================"
    echo "Detection Summary"
    echo "================================"
    echo "Partitions checked: $count"
    echo "Systems detected:   $detected"
    echo ""
    
    # Generate combined report
    generate_detection_report
}

#------------------------------------------------------------------------------
# Function: generate_detection_report
# Description: Create comprehensive detection report
#------------------------------------------------------------------------------
generate_detection_report() {
    local report="$DETECTION_DIR/detection-report.txt"
    
    cat > "$report" << REPORT
BFS System Detection Report
Generated: $(date)
========================================

DETECTED SYSTEMS
----------------
REPORT
    
    # Add each detected system
    for json in "$DETECTION_DIR"/os-detection-*.json; do
        if [ -f "$json" ]; then
            local device=$(grep -o '"device": "[^"]*"' "$json" | cut -d'"' -f4)
            local pretty=$(grep -o '"pretty_name": "[^"]*"' "$json" | cut -d'"' -f4)
            local family=$(grep -o '"family": "[^"]*"' "$json" | cut -d'"' -f4)
            local confidence=$(grep -o '"confidence": [0-9]*' "$json" | cut -d: -f2 | tr -d ' ')
            
            cat >> "$report" << SYSTEM

Device:     $device
System:     $pretty
Family:     $family
Confidence: $confidence%
SYSTEM
        fi
    done
    
    cat >> "$report" << FOOTER

HARDWARE SUMMARY
----------------
$(cat "$DETECTION_DIR/hardware-report.txt" 2>/dev/null || echo "Run hardware detection first")
FOOTER
    
    echo -e "${GREEN}✓ Full report: $report${NC}"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    if [ $# -eq 0 ]; then
        # Detect all systems
        detect_all_linux_systems
    else
        # Detect specific partition
        local device="$1"
        local mount_point="${2:-/mnt/bfs-temp}"
        
        mkdir -p "$mount_point"
        
        if mount -o ro "$device" "$mount_point" 2>/dev/null; then
            detect_os_on_partition "$device" "$mount_point"
            umount "$mount_point"
        else
            echo "Error: Could not mount $device"
            exit 1
        fi
    fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
