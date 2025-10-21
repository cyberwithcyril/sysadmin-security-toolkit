#!/bin/bash
################################################################################
# Script Name: create_user.sh
# Description: Creates user accounts with security policies
# Author: Cyril Thomas
# Date: October 21, 2025
# Version: 0.1 (skeleton)
#
# OS Concepts Demonstrated:
# - User/Group management (multi-user systems)
# - File system permissions and ownership
# - Process ownership and security contexts
#
# Security Features:
# - Input validation
# - Audit logging
# - Privilege validation
################################################################################

# Configuration
AUDIT_LOG="/var/log/sysadmin-toolkit/audit.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Function: log_action
# Purpose: Write audit trail entry
################################################################################
log_action() {
    local action="$1"
    local result="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] ACTION:$action RESULT:$result DETAILS:$details"
    # TODO: Write to actual log file
}

################################################################################
# Function: check_root
# Purpose: Verify script is running with root privileges
################################################################################
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: This script must be run as root${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Running with root privileges"
}

################################################################################
# Function: validate_username
# Purpose: Ensure username meets requirements
################################################################################
validate_username() {
    local username="$1"
    
    # Check if username provided
    if [ -z "$username" ]; then
        echo -e "${RED}ERROR: Username is required${NC}"
        return 1
    fi
    
    # Check length (3-32 characters)
    if [ ${#username} -lt 3 ] || [ ${#username} -gt 32 ]; then
        echo -e "${RED}ERROR: Username must be 3-32 characters${NC}"
        return 1
    fi
    
    # Check format (lowercase alphanumeric, underscore, hyphen)
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        echo -e "${RED}ERROR: Username must start with lowercase letter${NC}"
        echo "       and contain only lowercase letters, numbers, underscore, or hyphen"
        return 1
    fi
    
    # Check if username already exists
    if id "$username" &>/dev/null; then
        echo -e "${RED}ERROR: Username '$username' already exists${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Username validation passed"
    return 0
}

################################################################################
# Function: show_usage
# Purpose: Display help information
################################################################################
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Create user accounts with security policies.

Options:
    --username, -u USERNAME    Username for new account (required)
    --fullname, -f "NAME"      Full name of user (optional)
    --groups, -g GROUPS        Comma-separated list of groups (optional)
    --help, -h                 Show this help message

Examples:
    $0 --username jdoe --fullname "John Doe"
    $0 -u jsmith -f "Jane Smith" -g developers,sysadmins

Note: This is currently a skeleton script for testing.
      Actual user creation will be implemented in Day 4.

USAGE
}

################################################################################
# Main Script Execution
################################################################################

echo "========================================="
echo " User Creation Script (Skeleton v0.1)"
echo "========================================="
echo ""

# Test mode - just verify functions work
USERNAME="testuser001"
FULLNAME="Test User 001"

echo "Testing script functions with: $USERNAME"
echo ""

# Test privilege check
echo "1. Testing privilege check..."
check_root

echo ""

# Test username validation
echo "2. Testing username validation..."
if validate_username "$USERNAME"; then
    echo "   Username '$USERNAME' is valid!"
else
    echo "   Username validation failed"
fi

echo ""
echo "========================================="
echo " Script Skeleton Test Complete!"
echo "========================================="
echo ""
echo "Next steps (Day 4):"
echo "  - Add actual useradd functionality"
echo "  - Implement group management"
echo "  - Add password policy enforcement"
echo "  - Enable audit logging to file"
echo ""

log_action "SKELETON_TEST" "SUCCESS" "username=$USERNAME fullname='$FULLNAME'"

exit 0
