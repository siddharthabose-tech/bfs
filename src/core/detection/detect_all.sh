#!/bin/bash
# BFS Complete Detection Pipeline
# Hardware → Storage → OS Detection

set -e

readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORAGE_DIR="$SCRIPT_DIR/../storage"

echo ""
echo "========================================"
echo "BFS Complete System Detection"
echo "========================================"
echo ""

# Phase 1: Hardware Detection
echo -e "${BLUE}Phase 1: Hardware Detection${NC}"
echo "──────────────────────────────"
bash "$SCRIPT_DIR/hardware.sh"
echo ""

# Phase 2: Storage Stack Detection
echo -e "${BLUE}Phase 2: Storage Stack Detection${NC}"
echo "──────────────────────────────"
bash "$STORAGE_DIR/detect_storage.sh"
echo ""

# Phase 3: OS Detection
echo -e "${BLUE}Phase 3: OS Detection${NC}"
echo "──────────────────────────────"
# Use updated candidates list from storage detection
bash "$SCRIPT_DIR/os_detect.sh"
echo ""

# Final Report
echo "========================================"
echo "Detection Complete"
echo "========================================"
echo ""
echo "Reports generated in /tmp/bfs-detection/"
echo ""
echo "Key files:"
echo "  - hardware-report.txt"
echo "  - storage-stack-report.txt"
echo "  - detection-report.txt"
echo ""
echo -e "${GREEN}All systems detected and ready for repair!${NC}"
echo ""
