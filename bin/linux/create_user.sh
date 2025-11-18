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
# Function: show_usage
#*******************************************************************************
#Displays instructions for the user of how the create_user script works
#Examples of how the script works
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Options:
    -u, --username USERNAME    Username (required)
    -f, --fullname "NAME"      Full name (required)
    -g, --groups GROUPS        Groups (optional)
    -h, --help                 Help

Examples:
    $0 -u jdoe -f "John Doe"
    $0 -u jsmith -f "Jane Smith" -g developers,sudo

USAGE
}

#*******************************************************************************
# Function: interactive_menu
#*******************************************************************************
# Interactive menu for user creation
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux User Management"
        echo "========================================"
        echo ""
        echo "1. Create single user"
        echo "2. Create user with custom groups"
        echo "3. List existing users"
        echo "4. View audit log"
        echo ""
        echo "0. Exit to main menu"
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
                # List existing users
                clear
                echo ""
                echo "========================================"
                echo " Local Users (UID >= 1000)"
                echo "========================================"
                echo ""
                
                while IFS=: read -r username _ uid _ comment home _; do
                    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
                        echo "User: $username"
                        echo "  UID: $uid"
                        echo "  Name: $comment"
                        echo "  Home: $home"
                        echo ""
                    fi
                done < /etc/passwd
                
                read -p "Press Enter to continue..."
                ;;
                
            4)
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
                exit 0
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

print_header "User Creation Script v1.0"

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    # Command-line mode (original functionality)
    USERNAME=""
    FULLNAME=""
    GROUPS=""

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

    check_root

    if [ -z "$USERNAME" ] || [ -z "$FULLNAME" ]; then
        print_error "Username and fullname required"
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
else
    # Interactive mode (no arguments provided)
    check_root
    interactive_menu
fi