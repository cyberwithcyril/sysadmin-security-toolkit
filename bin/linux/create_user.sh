#!/bin/bash
#******************************************************************************
# Script Name: create_user.sh
# Description: Creates user accounts with security policies
# Author: Cyril Thomas
# Date: November 4, 2025
# Version: 1.0
#******************************************************************************

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

#*******************************************************************************
# Function: validate_username
#*******************************************************************************
#Checks if username is valid before creating a username using 4 checks 
#a. username is empty
#b. username length is valid - less than 3 char or greater than 32 char
#c. linux username rules - first char must be lowerchase - remaining char can be lowercase
#underscore, dot, or hyphen
#d. username already exists on the system
validate_username() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Username is required"
        return 1
    fi
    
    if [ ${#username} -lt 3 ] || [ ${#username} -gt 32 ]; then
        print_error "Username must be 3-32 characters"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-z][a-z0-9_.-]*$ ]]; then
        print_error "Username must start with lowercase letter"
        return 1
    fi
    
    if id "$username" &>/dev/null; then
        print_error "Username '$username' already exists"
        return 1
    fi
    
    print_success "Username validation passed"
    return 0
}

#*******************************************************************************
# Function: create_user_account
#*******************************************************************************
#Create a new user account with security settings, teemporary password and group assignment
create_user_account() {
    local username="$1"
    local fullname="$2"
    local groups="$3"
    
    echo ""
    print_info "Creating user account: $username"
    echo "----------------------------------------"
    
    # Create user
    #Ref:useradd is a linux command to create a new user 
    if useradd "$username" --create-home --shell /bin/bash --comment "$fullname" 2>/dev/null; then
        print_success "User account created"
    else
        print_error "Failed to create user"
        log_action "USER_CREATE" "FAILURE" "username=$username"
        return 1
    fi
    
    # Set permissions - New user can access home directory
    chmod 750 /home/"$username"
    chown "$username":"$username" /home/"$username"
    print_success "Home directory secured (750)"
    
    # Generate random password and encodes in base 64
    local temp_password=$(openssl rand -base64 12)
    #sets username with password
    echo "$username:$temp_password" | chpasswd
    print_success "Temporary password set"
    
    # Password policies
    #Ref:chage - Change age-command - Sets last password change date to 0
    chage -d 0 "$username"
    print_success "Password change required on first login"
    
    #Sets password age to 90 days
    chage -M 90 "$username"
    print_success "Password expires in 90 days"
    
    #Sets account expiration date
    local expire_date=$(date -d "+1 year" +%Y-%m-%d)
    chage -E "$expire_date" "$username"
    print_success "Account expires: $expire_date"
    
    # Adds user to groups defined in csv [faker data]
    if [ -n "$groups" ]; then
        IFS=',' read -ra GROUP_ARRAY <<< "$groups"
        for group in "${GROUP_ARRAY[@]}"; do
            if ! getent group "$group" >/dev/null 2>&1; then
                groupadd "$group"
                print_success "Created group: $group"
            fi
            usermod -aG "$group" "$username"
            print_success "Added to group: $group"
        done
    fi
    
    #Logs Action after user is created
    log_action "USER_CREATE" "SUCCESS" "username=$username fullname='$fullname'"
    
    echo ""
    echo -e "${GREEN}User created successfully!${NC}"
    echo "Username: $username"
    echo "Temporary Password: $temp_password"
    echo "Account expires: $expire_date"
    echo ""
    
    return 0
}

#*******************************************************************************
# Function: Disable User Account
#*******************************************************************************
disable_user_account() {
    local username="$1"
    local reason="${2:-Account disabled by administrator}"
    
    echo ""
    print_info "Disabling user account: $username"
    echo "----------------------------------------"
    
#Check if user exists
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist"
        log_action "USER_DISABLE" "FAILURE" "username=$username error=user_not_found"
        return 1
    fi
    
#Prevent disabling root or current, or user who ran sudo
    if [ "$username" == "root" ] || [ "$username" == "$SUDO_USER" ] || [ "$username" == "$(whoami)" ]; then
        print_error "Cannot disable root or current user"
        log_action "USER_DISABLE" "FAILURE" "username=$username error=protected_account"
        return 1
    fi
    
#Check if user already disabled
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        print_warning "User '$username' is already disabled"
        read -p "Continue anyway? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 0
        fi
    fi
    
#Lock the password
    if passwd -l "$username" &>/dev/null; then
        print_success "Password locked"
    else
        print_error "Failed to lock password"
        log_action "USER_DISABLE" "FAILURE" "username=$username error=lock_failed"
        return 1
    fi
    
 #Expire the account - Sets expiration of account to epoch day 0
    if chage -E 0 "$username" &>/dev/null; then
        print_success "Account expired"
    else
        print_warning "Could not expire account"
    fi
    
 #Extracts current shell from/etc/passwd, saves it to backup file, and then changes shell
 #to /sbin/nologin
    CURRENT_SHELL=$(grep "^$username:" /etc/passwd | cut -d: -f7)
    mkdir -p /var/backups/user-shells
    echo "$CURRENT_SHELL" > "/var/backups/user-shells/${username}_shell.bak"
    
    if usermod -s /sbin/nologin "$username" &>/dev/null; then
        print_success "Shell changed to /sbin/nologin"
    else
        print_warning "Could not change shell"
    fi
    
#Log the action
    log_action "USER_DISABLE" "SUCCESS" "username=$username reason='$reason'"
    
    echo ""
    echo -e "${GREEN}User '$username' has been disabled${NC}"
    echo "Reason: $reason"
    echo ""
    echo "Current status:"
    passwd -S "$username" 2>/dev/null
    echo ""
    
    return 0
}

#*******************************************************************************
# Function: Enable User Account
#*******************************************************************************
enable_user_account() {
    local username="$1"
    
    echo ""
    print_info "Enabling user account: $username"
    echo "----------------------------------------"
    
#Check if user exists
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist"
        log_action "USER_ENABLE" "FAILURE" "username=$username error=user_not_found"
        return 1
    fi
    
    local changes_made=false
    
#Check if password is locked - if locked unlocks
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        if passwd -u "$username" &>/dev/null; then
            print_success "Password unlocked"
            changes_made=true
        else
            print_error "Failed to unlock password"
        fi
    else
        print_info "Password is not locked"
    fi
    
#Check and remove account expiration
    EXPIRE_DATE=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    if [[ "$EXPIRE_DATE" == *"Jan 01, 1970"* ]] || [[ "$EXPIRE_DATE" == *"1970-01-01"* ]]; then
        if chage -E -1 "$username" &>/dev/null; then
            print_success "Account expiration removed"
            changes_made=true
        else
            print_warning "Could not remove expiration"
        fi
    else
        print_info "Account is not expired"
    fi
    
#Check and restore shell if nologin
    CURRENT_SHELL=$(grep "^$username:" /etc/passwd | cut -d: -f7)
    if [[ "$CURRENT_SHELL" == "/sbin/nologin" ]] || [[ "$CURRENT_SHELL" == "/usr/sbin/nologin" ]]; then
        SHELL_BACKUP="/var/backups/user-shells/${username}_shell.bak"
        
        if [ -f "$SHELL_BACKUP" ]; then
            ORIGINAL_SHELL=$(cat "$SHELL_BACKUP")
            if usermod -s "$ORIGINAL_SHELL" "$username" &>/dev/null; then
                print_success "Shell restored to: $ORIGINAL_SHELL"
                changes_made=true
            else
                print_warning "Could not restore shell"
            fi
        else
#No backup, use default
            if usermod -s /bin/bash "$username" &>/dev/null; then
                print_success "Shell set to: /bin/bash (default)"
                changes_made=true
            else
                print_warning "Could not set shell"
            fi
        fi
    else
        print_info "Shell is already set to: $CURRENT_SHELL"
    fi
    
    if $changes_made; then
        log_action "USER_ENABLE" "SUCCESS" "username=$username"
        echo ""
        echo -e "${GREEN}User '$username' has been enabled${NC}"
    else
        print_info "User '$username' appears to already be enabled"
    fi
    
    echo ""
    echo "Current status:"
    passwd -S "$username" 2>/dev/null
    echo ""
    
    return 0
}

#*******************************************************************************
# Function: View Disabled Users
#*******************************************************************************
list_disabled_users() {
    echo ""
    echo "========================================"
    echo " Disabled Users"
    echo "========================================"
    echo ""
    
    local found_disabled=false
    
#Reads through /etc/passwd line by line Filtering for regular users -6544
#Checks if each users password is locked - if locked - Displays username, UID, password status
#expiration date and current shell

    while IFS=: read -r username _ uid _ _ _ _; do
        if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
            # Check if password is locked
            if passwd -S "$username" 2>/dev/null | grep -q " L "; then
                found_disabled=true
                echo "User: $username"
                echo "  UID: $uid"
                
                # Get lock status
                PASS_STATUS=$(passwd -S "$username" 2>/dev/null)
                echo "  Status: $PASS_STATUS"
                
                # Get expiry
                EXPIRE=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                echo "  Expiry: $EXPIRE"
                
                # Get shell
                SHELL=$(grep "^$username:" /etc/passwd | cut -d: -f7)
                echo "  Shell: $SHELL"
                echo ""
            fi
        fi
    done < /etc/passwd
    
    if ! $found_disabled; then
        print_success "No disabled users found"
    fi
}

#*******************************************************************************
# Function: show_usage
#*******************************************************************************
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Options:
    -u, --username USERNAME    Username (required)
    -f, --fullname "NAME"      Full name (required for create)
    -g, --groups GROUPS        Groups (optional)
    -d, --disable              Disable user account
    -e, --enable               Enable user account
    -r, --reason "REASON"      Reason for disabling (optional)
    -h, --help                 Help

Examples:
    # Create user
    $0 -u jdoe -f "John Doe"
    $0 -u jsmith -f "Jane Smith" -g developers,sudo
    
    # Disable user
    $0 -u jdoe --disable
    $0 -u jdoe --disable -r "User on leave"
    
    # Enable user
    $0 -u jdoe --enable

USAGE
}

#*******************************************************************************
# Function: interactive_menu
#*******************************************************************************
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux User Management v2.0"
        echo "========================================"
        echo ""
        echo "USER CREATION:"
        echo "  1. Create single user"
        echo "  2. Create user with custom groups"
        echo ""
        echo "USER MANAGEMENT:"
        echo "  3. Disable user account"
        echo "  4. Enable user account"
        echo ""
        echo "INFORMATION:"
        echo "  5. List all users"
        echo "  6. List disabled users"
        echo "  7. View audit log"
        echo ""
        echo "  0. Exit to main menu"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1)
                # Create single user
                clear
                echo ""
                echo "========================================"
                echo " Create Single User"
                echo "========================================"
                echo ""
                
                read -p "Enter username: " username
                read -p "Enter full name: " fullname
                
                if [ -z "$username" ] || [ -z "$fullname" ]; then
                    print_error "Username and full name are required"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                if validate_username "$username"; then
                    create_user_account "$username" "$fullname" ""
                fi
                
                read -p "Press Enter to continue..."
                ;;
                
            2)
                # Create user with custom groups
                clear
                echo ""
                echo "========================================"
                echo " Create User with Groups"
                echo "========================================"
                echo ""
                
                read -p "Enter username: " username
                read -p "Enter full name: " fullname
                read -p "Enter groups (comma-separated, e.g., developers,sudo): " groups
                
                if [ -z "$username" ] || [ -z "$fullname" ]; then
                    print_error "Username and full name are required"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                if validate_username "$username"; then
                    create_user_account "$username" "$fullname" "$groups"
                fi
                
                read -p "Press Enter to continue..."
                ;;
                
            3)
                # Disable user (NEW)
                clear
                echo ""
                echo "========================================"
                echo " Disable User Account"
                echo "========================================"
                echo ""
                
                # Show enabled users
                echo "Currently enabled users:"
                while IFS=: read -r username _ uid _ _ _ _; do
                    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
                        # Check if not locked
                        if ! passwd -S "$username" 2>/dev/null | grep -q " L "; then
                            echo "  - $username"
                        fi
                    fi
                done < /etc/passwd
                echo ""
                
                read -p "Enter username to disable: " username
                
                if [ -z "$username" ]; then
                    print_error "Username is required"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                read -p "Enter reason for disabling (optional): " reason
                
                read -p "Disable user '$username'? (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if [ -z "$reason" ]; then
                        disable_user_account "$username"
                    else
                        disable_user_account "$username" "$reason"
                    fi
                else
                    print_info "Cancelled"
                fi
                
                read -p "Press Enter to continue..."
                ;;
                
            4)
                # Enable user (NEW)
                clear
                list_disabled_users
                
                read -p "Enter username to enable: " username
                
                if [ -z "$username" ]; then
                    print_error "Username is required"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                read -p "Enable user '$username'? (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    enable_user_account "$username"
                else
                    print_info "Cancelled"
                fi
                
                read -p "Press Enter to continue..."
                ;;
                
            5)
                # List all users
                clear
                echo ""
                echo "========================================"
                echo " Local Users (UID >= 1000)"
                echo "========================================"
                echo ""
                
                local total=0
                local enabled=0
                local disabled=0
                
                while IFS=: read -r username _ uid _ comment home _; do
                    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
                        total=$((total + 1))
                        
                        # Check if disabled
                        if passwd -S "$username" 2>/dev/null | grep -q " L "; then
                            disabled=$((disabled + 1))
                            STATUS="${RED}Disabled${NC}"
                        else
                            enabled=$((enabled + 1))
                            STATUS="${GREEN}Enabled${NC}"
                        fi
                        
                        echo "User: $username"
                        echo "  UID: $uid"
                        echo "  Name: $comment"
                        echo "  Home: $home"
                        echo -e "  Status: $STATUS"
                        echo ""
                    fi
                done < /etc/passwd
                
                echo "----------------------------------------"
                echo "Total users: $total"
                echo -e "${GREEN}Enabled: $enabled${NC}"
                echo -e "${RED}Disabled: $disabled${NC}"
                
                read -p "Press Enter to continue..."
                ;;
                
            6)
                # List disabled users (NEW)
                clear
                list_disabled_users
                read -p "Press Enter to continue..."
                ;;
                
            7)
                # View audit log
                clear
                echo ""
                echo "========================================"
                echo " Audit Log (Last 20 entries)"
                echo "========================================"
                echo ""
                
                if [ -f "$AUDIT_LOG" ]; then
                    tail -20 "$AUDIT_LOG"
                else
                    print_info "No audit log found yet"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            0)
                print_success "Returning to main menu..."
                return 0
                ;;
                
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

#*******************************************************************************
# Main - Controller
#*******************************************************************************

check_root

print_header "User Management Script v2.0"

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    USERNAME=""
    FULLNAME=""
    GROUPS=""
    ACTION="create"
    REASON=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--username)
                USERNAME="$2"
                shift 2
                ;;
            -f|--fullname)
                FULLNAME="$2"
                shift 2
                ;;
            -g|--groups)
                GROUPS="$2"
                shift 2
                ;;
            -d|--disable)
                ACTION="disable"
                shift
                ;;
            -e|--enable)
                ACTION="enable"
                shift
                ;;
            -r|--reason)
                REASON="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [ -z "$USERNAME" ]; then
        print_error "Username required"
        show_usage
        exit 1
    fi

    case $ACTION in
        create)
            if [ -z "$FULLNAME" ]; then
                print_error "Full name required for user creation"
                show_usage
                exit 1
            fi
            
            if ! validate_username "$USERNAME"; then
                exit 1
            fi
            
            if create_user_account "$USERNAME" "$FULLNAME" "$GROUPS"; then
                exit 0
            else
                exit 1
            fi
            ;;
            
        disable)
            if disable_user_account "$USERNAME" "$REASON"; then
                exit 0
            else
                exit 1
            fi
            ;;
            
        enable)
            if enable_user_account "$USERNAME"; then
                exit 0
            else
                exit 1
            fi
            ;;
    esac
else
    # Interactive mode
    interactive_menu
    exit 0
fi