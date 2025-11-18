#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script Name: sysadmin-toolkit.sh
# Description: Launcher for SysAdmin Toolkit (Linux & Windows)
# Author: Cyril Thomas
# Date: November 5, 2025
# Version: 1.0
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Colors [Adds Color to Text Output in Terminal]
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration 
#Defines script location - then Defines subfolder paths for Linux/Windows
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 
LINUX_BIN="$SCRIPT_DIR/bin/linux"
WINDOWS_BIN="$SCRIPT_DIR/bin/windows"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function: detect_os
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS_TYPE="Linux";;
        MINGW*|MSYS*|CYGWIN*)    OS_TYPE="Windows";;
        Darwin*)    OS_TYPE="Mac";;
        *)          OS_TYPE="Unknown";;
    esac
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function: show_banner
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Run Screen Banner/Displays Detected OS
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║          CTRL_OPS - SYSADMIN TOOLKIT                           ║"
    echo "║                     Version 1.0                                ║"
    echo "║                                                                ║"
    echo "║              Created by: Cyril Thomas                          ║"
    echo "║              Date: November 2025                               ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Show detected OS
    if [ "$OS_TYPE" == "Linux" ]; then
        echo -e "${GREEN}✓ Detected OS: Linux${NC}"
        echo -e "${GREEN}  All Linux tools available${NC}"
        echo ""
    elif [ "$OS_TYPE" == "Windows" ]; then
        echo -e "${BLUE}✓ Detected OS: Windows (Git Bash)${NC}"
        echo -e "${BLUE}  All Windows tools available${NC}"
        echo ""
    else
        echo -e "${RED}⚠ Detected OS: $OS_TYPE (Unsupported)${NC}"
        echo ""
    fi
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function: show_menu
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Menu Based On OS - Color Coded - Green if Linux & Blue if Windows - Red if Unsupported
#If/Else Condiiton -
show_menu() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    if [ "$OS_TYPE" == "Linux" ]; then
        echo -e "${GREEN}LINUX TOOLS:${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} User Management        - Create and Manage User Accounts"
        echo -e "  ${GREEN}2.${NC} Backup Automation      - Backup Files with compression"
        echo -e "  ${GREEN}3.${NC} Log Rotation           - Manage and Rotate System Logs"
        echo -e "  ${GREEN}4.${NC} System Monitoring      - Monitor CPU, Memory, Disk Usage"
        echo -e "  ${GREEN}5.${NC} Service Management     - Start, Stop, Restart Services"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}WINDOWS TOOLS: ${RED}(Not available on Linux)${NC}"
        echo ""
        echo -e "  ${RED}⚠${NC}  Windows tools require Windows OS or Git Bash on Windows"
        
    elif [ "$OS_TYPE" == "Windows" ]; then
        echo -e "${BLUE}WINDOWS TOOLS:${NC}"
        echo ""
        echo -e "  ${BLUE}1.${NC} User Management        - Create and Manage User Accounts"
        echo -e "  ${BLUE}2.${NC} Backup Automation      - Backup Files with Compression"
        echo -e "  ${BLUE}3.${NC} Event Log Management   - Archive and Manage Event Logs"
        echo -e "  ${BLUE}4.${NC} System Monitoring      - Monitor CPU, Memory, Disk Usage"
        echo -e "  ${BLUE}5.${NC} Service Management     - Start, Stop, Restart Services"
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}LINUX TOOLS: ${RED}(Not available on Windows)${NC}"
        echo ""
        echo -e "  ${RED}⚠${NC}  Linux tools require Linux OS"
        
    else
        echo -e "${RED}ERROR: Unsupported operating system${NC}"
        echo -e "This toolkit requires Linux or Windows (with Git Bash)"
        return
    fi
    
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}  6.${NC} About"
    echo ""
    echo -e "${RED}  0.${NC} Exit"
    echo ""
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function: run_linux_tool
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
run_linux_tool() {
    local tool="$1" #[User Management, Backup Automation, Log Rotation, System Monitoring,
    #Service Management]
    
    if [ "$OS_TYPE" != "Linux" ]; then
        echo -e "${RED}ERROR: This tool can only run on Linux!${NC}"
        echo -e "${YELLOW}Current OS: $OS_TYPE${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    case "$tool" in
        1) run_linux_user_management ;;
        2) run_linux_backup ;;
        3) run_linux_log_rotation ;;
        4) run_linux_monitoring ;;
        5) run_linux_service_management ;;
    esac
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function: run_windows_tool
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
run_windows_tool() {
    local tool="$1" #[User Management, Backup Automation, Event Log Management, System
    #Monitoring, Service Management]
    
    if [ "$OS_TYPE" != "Windows" ]; then
        echo -e "${RED}ERROR: This tool can only run on Windows!${NC}"
        echo -e "${YELLOW}Current OS: $OS_TYPE${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    case "$tool" in
        1) run_windows_user_management ;;
        2) run_windows_backup ;;
        3) run_windows_eventlog ;;
        4) run_windows_monitoring ;;
        5) run_windows_service_management ;;
    esac
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Linux Tool Functions
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

run_linux_user_management() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Linux User Management${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "1. Create single user"
    echo "2. Bulk create from CSV"
    echo "3. Back to main menu"
    echo ""
    read -p "Select: " choice
    
    case $choice in
        1)
            read -p "Username: " user
            read -p "Full name: " name
            sudo "$LINUX_BIN/create_user.sh" -u "$user" -f "$name"
            ;;
        2)
            read -p "CSV path: " csv
            sudo "$LINUX_BIN/create_users_from_csv.sh" "$csv"
            ;;
        3) return ;;
    esac
    read -p "Press Enter..."
}

run_linux_backup() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Linux Backup Automation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    sudo "$LINUX_BIN/backup_files.sh"
    echo ""
    read -p "Press Enter..."
}

run_linux_log_rotation() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Linux Log Rotation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching log rotation script..."
    cd "$SCRIPT_DIR"
    sudo "$LINUX_BIN/rotate_logs.sh"
}

run_linux_monitoring() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Linux System Monitoring${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching monitoring script..."
    cd "$SCRIPT_DIR"
    sudo "$LINUX_BIN/monitor_system.sh"
}

run_linux_user_management() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Linux User Management${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching user management script..."
    
    # Call script with NO arguments - triggers interactive menu
    cd "$SCRIPT_DIR"
    sudo "$LINUX_BIN/create_user.sh"
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Windows Tool Functions
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

run_windows_user_management() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Windows User Management${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching PowerShell script..."
    cd "$SCRIPT_DIR"
    powershell.exe -ExecutionPolicy Bypass -Command ". './bin/windows/New-BulkUsers.ps1'"
}

run_windows_backup() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Windows Backup Automation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching PowerShell script..."
    cd "$SCRIPT_DIR"
    powershell.exe -ExecutionPolicy Bypass -Command ". './bin/windows/Backup-Files.ps1'"
}

run_windows_eventlog() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Windows Event Log Management${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching PowerShell script..."
    cd "$SCRIPT_DIR"
    powershell.exe -ExecutionPolicy Bypass -Command ". './bin/windows/Manage-EventLogs.ps1'"
}

run_windows_monitoring() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Windows System Monitoring${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching PowerShell script..."
    cd "$SCRIPT_DIR"
    powershell.exe -ExecutionPolicy Bypass -Command ". './bin/windows/Monitor-System.ps1'"
}

run_windows_service_management() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Windows Service Management${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "Launching PowerShell script..."
    cd "$SCRIPT_DIR"
    powershell.exe -ExecutionPolicy Bypass -Command ". './bin/windows/Manage-Service.ps1'"
}


show_about() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  About SysAdmin Toolkit${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "SysAdmin Toolkit - Universal Edition"
    echo "Version: 1.0"
    echo "Created: November 2025"
    echo "Author: Cyril Thomas"
    echo ""
    echo "Cross-platform system administration automation toolkit "
    echo ""
    echo "Technology Stack:"
    echo "  • Bash "
    echo "  • PowerShell"
    echo ""
    echo "Platforms Supported:"
    echo "  • Linux (Ubuntu, CentOS, etc.)"
    echo "  • Windows Server (2019, 2022)"
    echo "  • Windows 10/11 (with Git Bash)"
    echo ""
    read -p "Press Enter..."
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Main Loop - CORE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Detect OS
detect_os

# Check Git Bash on Windows
if [ "$OS_TYPE" == "Windows" ] && ! command -v powershell.exe &> /dev/null; then
    echo -e "${RED}ERROR: PowerShell not found!${NC}"
    echo "This toolkit requires PowerShell on Windows"
    exit 1
fi

# Main menu loop
while true; do
    show_banner
    show_menu
    
    read -p "Select an option: " choice
    
    case $choice in
        1|2|3|4|5)
            if [ "$OS_TYPE" == "Linux" ]; then
                run_linux_tool "$choice"
            elif [ "$OS_TYPE" == "Windows" ]; then
                run_windows_tool "$choice"
            fi
            ;;
        6)
            show_about
            ;;
        0)
            clear
            echo -e "${GREEN}Thank you for using SysAdmin Toolkit!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
