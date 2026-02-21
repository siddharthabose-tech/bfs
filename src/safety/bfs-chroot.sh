#!/bin/bash
# BFS Safe Chroot Wrapper (WSL2 Compatible)

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Log file
readonly LOG_FILE="/var/log/bfs/operations.log"
mkdir -p /var/log/bfs 2>/dev/null || true

log_operation() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] CHROOT: $*" >> "$LOG_FILE" 2>/dev/null || true
}

mount_system_directories() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Mounting system directories...${NC}"
    
    # Mount proc
    mkdir -p "$chroot_dir/proc"
    if ! mount | grep -q "$chroot_dir/proc"; then
        mount -t proc proc "$chroot_dir/proc" && echo "  ✓ Mounted proc"
    fi
    
    # Mount sysfs  
    mkdir -p "$chroot_dir/sys"
    if ! mount | grep -q "$chroot_dir/sys"; then
        mount -t sysfs sysfs "$chroot_dir/sys" && echo "  ✓ Mounted sys"
    fi
    
    # Mount tmpfs for /run
    mkdir -p "$chroot_dir/run"
    if ! mount | grep -q "$chroot_dir/run"; then
        mount -t tmpfs tmpfs "$chroot_dir/run" 2>/dev/null && echo "  ✓ Mounted run"
    fi
    
    # Try to bind /dev (skip if fails in WSL2)
    mkdir -p "$chroot_dir/dev"
    if mount --bind /dev "$chroot_dir/dev" 2>/dev/null; then
        echo "  ✓ Mounted dev"
    else
        echo "  ⚠ Skipped /dev (WSL2 limitation, not critical)"
    fi
    
    # Copy DNS
    cp /etc/resolv.conf "$chroot_dir/etc/resolv.conf" 2>/dev/null && echo "  ✓ Copied DNS config"
    
    echo -e "${GREEN}✓ System directories ready${NC}"
}

unmount_system_directories() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Cleaning up...${NC}"
    
    umount "$chroot_dir/dev" 2>/dev/null || true
    umount "$chroot_dir/run" 2>/dev/null || true
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

validate_chroot_target() {
    local chroot_dir="$1"
    
    echo -e "${BLUE}[Chroot] Validating target...${NC}"
    
    if [ ! -d "$chroot_dir" ]; then
        echo -e "${RED}✗ Directory not found${NC}"
        return 1
    fi
    
    for dir in bin etc lib usr; do
        if [ ! -d "$chroot_dir/$dir" ]; then
            echo -e "${RED}✗ Missing: $dir${NC}"
            return 1
        fi
    done
    
    if [ -f "$chroot_dir/etc/os-release" ]; then
        local os_name=$(grep ^NAME= "$chroot_dir/etc/os-release" | cut -d'"' -f2)
        echo "  Target OS: $os_name"
    fi
    
    echo -e "${GREEN}✓ Valid Linux root${NC}"
    return 0
}

safe_chroot() {
    local chroot_dir="$1"
    shift
    local command=("$@")
    
    echo ""
    echo "================================"
    echo "BFS Safe Chroot"
    echo "================================"
    echo "Target: $chroot_dir"
    echo ""
    
    validate_chroot_target "$chroot_dir" || return 1
    echo ""
    
    mount_system_directories "$chroot_dir"
    echo ""
    
    trap "unmount_system_directories '$chroot_dir'" EXIT
    
    log_operation "Entering: $chroot_dir"
    echo -e "${GREEN}Entering chroot...${NC}"
    echo ""
    
    if [ ${#command[@]} -eq 0 ]; then
        chroot "$chroot_dir" /bin/bash
    else
        chroot "$chroot_dir" "${command[@]}"
    fi
    
    echo ""
    echo -e "${GREEN}Exited chroot${NC}"
    log_operation "Exited: $chroot_dir"
}

main() {
    if [ $# -lt 1 ]; then
        echo "Usage: bfs-chroot <directory> [command]"
        exit 1
    fi
    
    safe_chroot "$@"
}

main "$@"
