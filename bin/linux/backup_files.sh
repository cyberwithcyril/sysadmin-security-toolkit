#!/bin/bash
#******************************************************************************
# Script Name: backup_files.sh
# Description: Automated file backup with compression and rotation
# Author: Cyril Thomas
# Date: November 4, 2025
# Version: 1.0
#******************************************************************************

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Configuration
#Directory 'home'
BACKUP_SOURCE="/home"
#Backed up 'backup' dir
BACKUP_DEST="/backup"
#Time frame
RETENTION_DAYS=7

#*******************************************************************************
# Function: validate_paths
#*******************************************************************************
#Function ensures path for backup source and destination exists - Creates if necessary
validate_paths() {
    print_info "Validating backup paths..."
    
    # Check source directory 'home' exists
    if [ ! -d "$BACKUP_SOURCE" ]; then
        print_error "Source directory does not exist: $BACKUP_SOURCE"
        return 1
    fi
    print_success "Source path valid: $BACKUP_SOURCE"
    
    # Create destination if needed
    if [ ! -d "$BACKUP_DEST" ]; then
        mkdir -p "$BACKUP_DEST"
    #Sets permissions to owner:read/write/execute, others: read/execute
        chmod 755 "$BACKUP_DEST"
        print_success "Created destination: $BACKUP_DEST"
    else
        print_success "Destination path valid: $BACKUP_DEST"
    fi
    
    return 0
}

################################################################################
# Function: calculate_size
################################################################################
calculate_size() {
    local path="$1"
    local size=$(du -sh "$path" 2>/dev/null | cut -f1)
    echo "$size"
}

################################################################################
# Function: check_disk_space
################################################################################
check_disk_space() {
    print_info "Checking available disk space..."
    
    local available=$(df -h "$BACKUP_DEST" | awk 'NR==2 {print $4}')
    local used=$(df -h "$BACKUP_DEST" | awk 'NR==2 {print $3}')
    
    print_success "Available space: $available"
    print_success "Used space: $used"
    
    return 0
}

################################################################################
# Function: create_backup
################################################################################
create_backup() {
    local source="$1"
    local dest="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="backup_$(basename $source)_${timestamp}.tar.gz"
    local backup_path="${dest}/${backup_name}"
    
    print_info "Creating backup: $backup_name"
    
    # Get source size
    local source_size=$(calculate_size "$source")
    print_info "Source size: $source_size"
    
    # Create compressed backup
    if tar -czf "$backup_path" -C "$(dirname $source)" "$(basename $source)" 2>/dev/null; then
        print_success "Backup created successfully"
        
        # Get backup size
        local backup_size=$(calculate_size "$backup_path")
        print_success "Backup size: $backup_size"
        print_success "Saved to: $backup_path"
        
        # Calculate compression ratio
        log_action "BACKUP_CREATE" "SUCCESS" "source=$source size=$backup_size file=$backup_name"
        
        return 0
    else
        print_error "Failed to create backup"
        log_action "BACKUP_CREATE" "FAILURE" "source=$source"
        return 1
    fi
}

#*******************************************************************************
# Function: rotate_backups
#*******************************************************************************
#Function implements backup rotation - Automatically deleting old backup files based on set retention
rotate_backups() {
    local dest="$1" #Backup destination
    local retention="$2" #Number of days to keep backup
    
    print_info "Rotating old backups (keeping last $retention days)..."
    
    # Find and delete old backups
    local deleted_count=0
    
    #Deletion
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Deleted: $(basename $file)"
            ((deleted_count++))
        fi
    #Checks destination for file names starting with backup_using wildcard* and checks time comparing it to 
    #retention set

    done < <(find "$dest" -name "backup_*.tar.gz" -type f -mtime +$retention)
    
    if [ $deleted_count -eq 0 ]; then
        print_info "No old backups to delete"
    else
        print_success "Deleted $deleted_count old backup(s)"
        log_action "BACKUP_ROTATE" "SUCCESS" "deleted=$deleted_count retention=${retention}d"
    fi
    
    return 0
}

#******************************************************************************
# Function: list_backups
#******************************************************************************
#Function list all backup files with their sizes and dates
#Takes the backups from destination and prints
list_backups() {
    local dest="$1"
    
    print_info "Current backups in $dest:"
    echo ""
#Checks if backups exists
    if [ ! -d "$dest" ] || [ -z "$(ls -A $dest)" ]; then
        echo "  No backups found"
        return 0
    fi
#Prints destination - ignores error messages and formats to readable format - Example: `backup_20251115.tar.gz - 2.3M - Nov 15 14:30`  
    ls -lh "$dest"/backup_*.tar.gz 2>/dev/null | awk '{print "  " $9 " - " $5 " - " $6 " " $7 " " $8}' || echo "  No backups found"
    echo ""
    
    return 0
}

#******************************************************************************
# Function: show_usage
#******************************************************************************
#Creates/display help instructions for the user
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Options:
    -s, --source PATH       Source directory to backup (default: /home)
    -d, --dest PATH         Backup destination (default: /backup)
    -r, --retention DAYS    Days to keep backups (default: 7)
    -l, --list              List existing backups
    -h, --help              Show this help

Examples:
    $0                                          # Backup /home to /backup
    $0 -s /var/www -d /backup/www              # Backup custom path
    $0 -r 14                                    # Keep backups for 14 days
    $0 -l                                       # List existing backups

USAGE
}

#*******************************************************************************
# Function: interactive_menu
#*******************************************************************************
# Interactive menu for backup operations
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux Backup Automation"
        echo "========================================"
        echo ""
        echo "Configuration:"
        echo "  Source: $BACKUP_SOURCE"
        echo "  Destination: $BACKUP_DEST"
        echo "  Retention: $RETENTION_DAYS days"
        echo ""
        echo "1. Create backup now"
        echo "2. List current backups"
        echo "3. Check disk space"
        echo "4. Rotate old backups"
        echo "5. Custom backup (choose source)"
        echo "6. Full backup cycle (backup + rotate)"
        echo ""
        echo "0. Exit to main menu"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1)
                # Create backup now
                clear
                print_info "Starting backup..."
                echo ""
                
                if validate_paths && check_disk_space; then
                    echo ""
                    if create_backup "$BACKUP_SOURCE" "$BACKUP_DEST"; then
                        print_success "Backup completed!"
                    else
                        print_error "Backup failed!"
                    fi
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            2)
                # List current backups
                clear
                list_backups "$BACKUP_DEST"
                read -p "Press Enter to continue..."
                ;;
                
            3)
                # Check disk space
                clear
                check_disk_space
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            4)
                # Rotate old backups
                clear
                print_info "Checking for old backups..."
                echo ""
                rotate_backups "$BACKUP_DEST" "$RETENTION_DAYS"
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            5)
                # Custom backup
                clear
                print_info "Custom Backup"
                echo ""
                read -p "Enter source path (e.g., /var/www): " custom_source
                
                if [ -d "$custom_source" ]; then
                    print_info "Source: $custom_source"
                    read -p "Proceed with backup? (yes/no): " confirm
                    
                    if [ "$confirm" = "yes" ]; then
                        echo ""
                        if validate_paths && check_disk_space; then
                            echo ""
                            if create_backup "$custom_source" "$BACKUP_DEST"; then
                                print_success "Custom backup completed!"
                            else
                                print_error "Backup failed!"
                            fi
                        fi
                    else
                        print_info "Backup cancelled"
                    fi
                else
                    print_error "Source path does not exist!"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            6)
                # Full backup cycle
                clear
                echo "========================================"
                echo " Full Backup Cycle"
                echo "========================================"
                echo ""
                
                if validate_paths && check_disk_space; then
                    echo ""
                    if create_backup "$BACKUP_SOURCE" "$BACKUP_DEST"; then
                        echo ""
                        rotate_backups "$BACKUP_DEST" "$RETENTION_DAYS"
                        echo ""
                        list_backups "$BACKUP_DEST"
                        echo ""
                        print_success "Full backup cycle completed!"
                    else
                        print_error "Backup failed!"
                    fi
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
# Main Function 
#*******************************************************************************

print_header "Backup Script v1.0"

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    # Command-line mode (original functionality)
    LIST_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                BACKUP_SOURCE="$2"
                shift 2
                ;;
            -d|--dest)
                BACKUP_DEST="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
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

    # Configuration summary
    echo "Configuration:"
    echo "  Source: $BACKUP_SOURCE"
    echo "  Destination: $BACKUP_DEST"
    echo "  Retention: $RETENTION_DAYS days"
    echo ""

    # List only mode
    if [ "$LIST_ONLY" = true ]; then
        list_backups "$BACKUP_DEST"
        exit 0
    fi

    # Validate paths
    if ! validate_paths; then
        exit 1
    fi

    # Check disk space
    check_disk_space

    echo ""

    # Create backup
    if create_backup "$BACKUP_SOURCE" "$BACKUP_DEST"; then
        echo ""
        
        # Rotate old backups
        rotate_backups "$BACKUP_DEST" "$RETENTION_DAYS"
        
        echo ""
        
        # Show current backups
        list_backups "$BACKUP_DEST"
        
        print_success "Backup completed successfully!"
        exit 0
    else
        print_error "Backup failed!"
        exit 1
    fi
else
    # Interactive mode (no arguments provided)
    check_root
    interactive_menu
    exit 0
fi