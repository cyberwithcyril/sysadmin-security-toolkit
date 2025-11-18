#!/bin/bash
#**********************************************************************************
# File: common.sh
# Description: Shared Library file
# Author: Cyril Thomas
# Date: November 4, 2025
#***********************************************************************************

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Configuration
export LOG_DIR="/var/log/sysadmin-toolkit"
export AUDIT_LOG="$LOG_DIR/audit.log"

#*******************************************************************************
# Function: log_action
#*******************************************************************************
log_action() {
    local action="$1"
    local result="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
    
    # Write to log
    echo "[$timestamp] ACTION:$action RESULT:$result DETAILS:$details" | tee -a "$AUDIT_LOG"
}

#**********************************************************************************
# Function: check_root
#***********************************************************************************
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: This script must be run as root${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Running with root privileges"
}

#******************************************************************************
# Function: print_header
#*******************************************************************************
print_header() {
    local title="$1"
    echo "========================================="
    echo " $title"
    echo "========================================="
    echo ""
}

#*****************************************************************************
# Function: print_success
#******************************************************************************
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

#******************************************************************************
# Function: print_error
#*******************************************************************************
print_error() {
    echo -e "${RED}✗${NC} $1"
}

#******************************************************************************
# Function: print_info
#*******************************************************************************
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

#*******************************************************************************
# Function: print_warning
#********************************************************************************
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}
