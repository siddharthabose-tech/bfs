#!/bin/bash
# BFS Safe Chroot Wrapper
# Ensures proper mount setup before chrooting

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Log file
readonly LOG_FILE="/var/log/bfs/operations.log"

#------------------------------------------------------------------------------
# Function: log_operation
#------------------------------------------------------------------------------
log_operation() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] CHROOT: $*" >> "$LOG_FILE"
}

#------------------------------------------------------------------------------
# Function: mount_system_directories
# Description: Mount required system directories for chroot
#------------------------------------------------------------------------------
mount_system_directories() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Mounting system directories...${NC}"
    
    # Required mounts for functional chroot
    local mounts=(
        "proc:$chroot_dir/proc:proc:none"
        "sys:$chroot_dir/sys:sysfs:none"
        "dev:$chroot_dir/dev:none:bind"
        "devpts:$chroot_dir/dev/pts:devpts:none"
        "run:$chroot_dir/run:none:bind"
    )
    
    for mount_spec in "${mounts[@]}"; do
        IFS=':' read -r src dst type options <<< "$mount_spec"
        
        # Create mount point if needed
        mkdir -p "$dst"
        
        # Check if already mounted
        if mount | grep -q "$dst"; then
            echo "  ✓ $dst already mounted"
            continue
        fi
        
        # Mount
        if [ "$type" = "none" ]; then
            mount -o "$options" "$src" "$dst"
        else
            mount -t "$type" "$src" "$dst"
        fi
        
        echo "  ✓ Mounted $dst"
    done
    
    # Copy DNS configuration
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "$chroot_dir/etc/resolv.conf"
        echo "  ✓ Copied DNS configuration"
    fi
    
    echo -e "${GREEN}✓ System directories mounted${NC}"
}

#------------------------------------------------------------------------------
# Function: unmount_system_directories
# Description: Clean up mounts after chroot
#------------------------------------------------------------------------------
unmount_system_directories() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Unmounting system directories...${NC}"
    
    # Unmount in reverse order
    local dirs=(
        "$chroot_dir/dev/pts"
        "$chroot_dir/dev"
        "$chroot_dir/run"
        "$chroot_dir/sys"
        "$chroot_dir/proc"
    )
    
    for dir in "${dirs[@]}"; do
        if mount | grep -q "$dir"; then
            umount "$dir" 2>/dev/null || umount -l "$dir"
            echo "  ✓ Unmounted $dir"
        fi
    done
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#------------------------------------------------------------------------------
# Function: validate_chroot_target
# Description: Check if directory is a valid Linux root
#------------------------------------------------------------------------------
validate_chroot_target() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Validating target directory...${NC}"
    
    # Check if directory exists
    if [ ! -d "$chroot_dir" ]; then
        echo -e "${RED}✗ Error: Directory does not exist: $chroot_dir${NC}"
        return 1
    fi
    
    # Check for essential directories
    local required_dirs=("bin" "etc" "lib" "usr")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$chroot_dir/$dir" ]; then
            echo -e "${RED}✗ Error: Missing directory: $dir${NC}"
            echo "This doesn't look like a Linux root filesystem"
            return 1
        fi
    done
    
    # Check for shell
    if [ ! -f "$chroot_dir/bin/bash" ] && [ ! -f "$chroot_dir/bin/sh" ]; then
        echo -e "${RED}✗ Error: No shell found${NC}"
        return 1
    fi
    
    # Check /etc/os-release if present
    if [ -f "$chroot_dir/etc/os-release" ]; then
        local os_name=$(grep ^NAME= "$chroot_dir/etc/os-release" | cut -d'"' -f2)
        echo "  Target OS: $os_name"
    fi
    
    echo -e "${GREEN}✓ Target is valid Linux root${NC}"
    return 0
}

#------------------------------------------------------------------------------
# Function: safe_chroot
# Description: Perform chroot with proper setup
#------------------------------------------------------------------------------
safe_chroot() {
    local chroot_dir="$1"
    shift
    local command=("$@")
    
    echo ""
    echo "================================"
    echo "BFS Safe Chroot"
    echo "================================"
    echo ""
    echo "Target:  $chroot_dir"
    echo "Command: ${command[*]:-/bin/bash}"
    echo ""
    
    # Validate target
    if ! validate_chroot_target "$chroot_dir"; then
        return 1
    fi
    
    echo ""
    
    # Setup mounts
    mount_system_directories "$chroot_dir"
    
    echo ""
    log_operation "Entering chroot: $chroot_dir"
    
    # Setup cleanup trap
    trap "unmount_system_directories '$chroot_dir'" EXIT
    
    # Enter chroot
    echo -e "${GREEN}Entering chroot environment...${NC}"
    echo -e "${YELLOW}(Type 'exit' to leave)${NC}"
    echo ""
    
    if [ ${#command[@]} -eq 0 ]; then
        chroot "$chroot_dir" /bin/bash
    else
        chroot "$chroot_dir" "${command[@]}"
    fi
    
    local exit_code=$?
    
    echo ""
    echo -e "${GREEN}Exited chroot${NC}"
    log_operation "Exited chroot: $chroot_dir (exit code: $exit_code)"
    
    return $exit_code
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: bfs-chroot <chroot_directory> [command]"
        echo ""
        echo "Examples:"
        echo "  bfs-chroot /mnt"
        echo "  bfs-chroot /mnt apt update"
        echo "  bfs-chroot /mnt /bin/bash"
        exit 1
    fi
    
    safe_chroot "$@"
}

main "$@"
