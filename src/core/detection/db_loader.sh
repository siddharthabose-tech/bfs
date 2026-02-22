#!/bin/bash
# BFS Distro Database Loader
# Loads and queries distro database

readonly DB_DIR="data/distros"

#------------------------------------------------------------------------------
# Function: load_distro_info
# Description: Load YAML info for a specific distro
# Arguments: $1 - distro ID (e.g., "ubuntu")
#------------------------------------------------------------------------------
load_distro_info() {
    local distro_id="$1"
    
    # Check tier1 first
    local distro_file="$DB_DIR/tier1/$distro_id.yaml"
    
    if [ ! -f "$distro_file" ]; then
        # Check tier2
        distro_file="$DB_DIR/tier2/$distro_id.yaml"
    fi
    
    if [ ! -f "$distro_file" ]; then
        echo "ERROR: Distro not in database: $distro_id"
        return 1
    fi
    
    # For now, just cat the file
    # In production, we'd use a YAML parser (yq)
    cat "$distro_file"
    return 0
}

#------------------------------------------------------------------------------
# Function: get_distro_field
# Description: Extract a specific field from distro YAML
# Arguments: $1 - distro ID, $2 - field path (e.g., "boot.bootloader")
#------------------------------------------------------------------------------
get_distro_field() {
    local distro_id="$1"
    local field="$2"
    
    local yaml=$(load_distro_info "$distro_id")
    
    # Simple grep-based extraction (would use yq in production)
    echo "$yaml" | grep "^  $field:" | cut -d: -f2- | xargs
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <distro-id> [field]"
        echo ""
        echo "Example:"
        echo "  $0 ubuntu"
        echo "  $0 ubuntu boot"
        exit 1
    fi
    
    if [ $# -eq 1 ]; then
        load_distro_info "$1"
    else
        get_distro_field "$1" "$2"
    fi
fi
