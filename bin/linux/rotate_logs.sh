#!/bin/bash
#******************************************************************************
# Script Name: rotate_logs.sh
# Description: Automated log rotation, compression, and cleanup
# Author: Cyril Thomas
# Date: November 4, 2025
# Version: 1.0
#*******************************************************************************

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Configuration
LOG_DIRS=("/var/log") #Array of Directories to monitor
MAX_SIZE_MB=50 #Threshold for large log files
RETENTION_DAYS=30 #Keep Logs Before Deletion
COMPRESS_AFTER_DAYS=7 #Logs Older than 7 Days Get Compressed

#*******************************************************************************
# Function: find_large_logs
#*******************************************************************************
#Function finds log files exceeding the size threshold

find_large_logs() {
#Get size parameter of log file
    local max_size_mb="$1"
    
    print_info "Scanning for large log files (>${max_size_mb}MB)..."
    
#Initialize Counter - Tracks large files found
    local count=0

#Loops through each found file - Verifies if file exists, Extracts first field [file size]
#increments counter
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local size=$(du -h "$file" | cut -f1)
            echo "  Found: $file ($size)"
            ((count++))
        fi
    done < <(find "${LOG_DIRS[@]}" -type f -name "*.log" -size +${max_size_mb}M 2>/dev/null)

#Display summary if no large files/# of large log files 
    if [ $count -eq 0 ]; then
        print_success "No large log files found"
    else
        print_warning "Found $count large log file(s)"
    fi
    
    return $count
}

#*******************************************************************************
# Function: find_old_logs
#*******************************************************************************
#Finds logs older than retention period [30], Displayes each old file with modification date,
#count and reports total

find_old_logs() {
    local retention_days="$1"
    
    print_info "Scanning for old log files (>${retention_days} days)..."
    
    local count=0

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local age=$(find "$file" -mtime +$retention_days -printf "%TY-%Tm-%Td\n" 2>/dev/null)
            echo "  Found: $file (modified: $age)"
            ((count++))
        fi

#Finds log files matching three patterns - .log [active logs], .log.1,.log.2 [rotated logs].
#.gz [Compressed logs]
    done < <(find "${LOG_DIRS[@]}" -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.gz" \) -mtime +$retention_days 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_success "No old log files to delete"
    else
        print_warning "Found $count old log file(s)"
    fi
    
    return $count
}

#******************************************************************************
# Function: compress_log
#*******************************************************************************

compress_log() {

#Get logfile path    
    local logfile="$1"
#Verify FIle Exists   
    if [ ! -f "$logfile" ]; then
        return 1
    fi
    
#Checks if logfile is compressed by checking against wild card *.gz - Returns 0
    if [[ "$logfile" == *.gz ]]; then
        return 0
    fi

#Get size before compression  
    local size_before=$(du -h "$logfile" | cut -f1)

#Compresses the file - command gzip [compression] -f [force]    
    if gzip -f "$logfile" 2>/dev/null; then
       
#Gets new compressed size of log file
        local size_after=$(du -h "${logfile}.gz" | cut -f1)
        print_success "Compressed: $(basename $logfile) ($size_before → $size_after)"
#Logs Log Compression Action      
        log_action "LOG_COMPRESS" "SUCCESS" "file=$(basename $logfile) size_before=$size_before size_after=$size_after"
        return 0
    else
        print_error "Failed to compress: $(basename $logfile)"
        return 1
    fi
}

#******************************************************************************
# Function: delete_old_log
#******************************************************************************
#Verifies file exists, records file size before deletion, deletes the file, displays confirmation
delete_old_log() {

#Gets log file path
    local logfile="$1"

#Verifies Log File Exists   
    if [ ! -f "$logfile" ]; then
        return 1
    fi
#Gets record size for logging before deletion    
    local size=$(du -h "$logfile" | cut -f1)

#Deletes the file using the rm[remove command] -f [force]   
    if rm -f "$logfile" 2>/dev/null; then
        print_success "Deleted: $(basename $logfile) ($size)"

#Logs Action      
        log_action "LOG_DELETE" "SUCCESS" "file=$(basename $logfile) size=$size"
        return 0
    else
        print_error "Failed to delete: $(basename $logfile)"
        return 1
    fi
}

#******************************************************************************
# Function: rotate_logs
#******************************************************************************
#Manages files that have been rotated - Log Clean up

rotate_logs() {
    print_info "Starting log rotation process..."
    echo ""

#Initialize Counters   
    local compressed_count=0 #Compressed file counter
    local deleted_count=0 #Deleted file counter
    
#Compress logs older than COMPRESS_AFTER_DAYS [7 Days]
    print_info "Step 1: Compressing old uncompressed logs..."
  
#Processes one file at a time
    while IFS= read -r file; do

#Checks if it is a real file and that file is not already compressed     
        if [ -f "$file" ] && [[ "$file" != *.gz ]]; then
            if compress_log "$file"; then
                ((compressed_count++))
            fi
        fi
#Provides the list of files to compress
    done < <(find "${LOG_DIRS[@]}" -type f -name "*.log.*" -mtime +$COMPRESS_AFTER_DAYS ! -name "*.gz" 2>/dev/null)

#Checks if Nothing was compressed    
    if [ $compressed_count -eq 0 ]; then
        print_info "  No logs to compress"
    fi
    
    echo ""
    
 # Delete logs older than RETENTION_DAYS
    print_info "Step 2: Deleting old logs..."

#Checks if file exists
    while IFS= read -r file; do

#If the log exists then call the delete_old_log function
        if [ -f "$file" ]; then
            if delete_old_log "$file"; then
                ((deleted_count++))
            fi
        fi
#Finds files rotated - .log. or compressed -*.gz using retention time - older than 30 days
    done < <(find "${LOG_DIRS[@]}" -type f \( -name "*.log.*" -o -name "*.gz" \) -mtime +$RETENTION_DAYS 2>/dev/null)
    
    if [ $deleted_count -eq 0 ]; then
        print_info "  No old logs to delete"
    fi
    
    echo ""
#Displays Rotation Summary
    print_header "Rotation Summary"
    echo "Compressed: $compressed_count log file(s)"
    echo "Deleted: $deleted_count log file(s)"

#Logs Rotation Action   
    log_action "LOG_ROTATION" "SUCCESS" "compressed=$compressed_count deleted=$deleted_count"
    
    return 0
}

#******************************************************************************
# Function: show_log_stats
#******************************************************************************
#Function Displays Log Directory Statistics

show_log_stats() {
    print_info "Log directory statistics:"
    echo ""

#Iterates through directory
    for dir in "${LOG_DIRS[@]}"; do
#If directory exists
        if [ -d "$dir" ]; then
#Gets total size of the directory
            local total_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
#Count log files
            local log_count=$(find "$dir" -type f \( -name "*.log" -o -name "*.log.*" \) 2>/dev/null | wc -l)
#Count compressed .gz files           
            local gz_count=$(find "$dir" -type f -name "*.gz" 2>/dev/null | wc -l)

#Displays directory name, total size, total count of lofs, total compressed files           
            echo "  Directory: $dir"
            echo "    Total size: $total_size"
            echo "    Log files: $log_count"
            echo "    Compressed: $gz_count"
            echo ""
        fi
    done
}

#******************************************************************************
# Function: show_usage
#******************************************************************************
#Help-Usage Manaul for Rotate_Logs Script
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Options:
    -d, --dirs DIRS         Log directories to monitor (default: /var/log)
    -s, --size MB           Max log size in MB (default: 50)
    -r, --retention DAYS    Days to keep logs (default: 30)
    -c, --compress DAYS     Compress logs after DAYS (default: 7)
    --scan                  Scan only (no changes)
    --stats                 Show log statistics
    -h, --help              Show this help

Examples:
    $0                              # Run with defaults
    $0 -r 60 -c 14                  # Keep 60 days, compress after 14
    $0 --scan                       # Scan without making changes
    $0 --stats                      # Show log statistics

USAGE
}

#******************************************************************************
# Function: interactive_menu
#******************************************************************************
# Interactive menu for log rotation operations
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux Log Rotation"
        echo "========================================"
        echo ""
        echo "Configuration:"
        echo "  Directories: ${LOG_DIRS[*]}"
        echo "  Max size: ${MAX_SIZE_MB}MB"
        echo "  Retention: ${RETENTION_DAYS} days"
        echo "  Compress after: ${COMPRESS_AFTER_DAYS} days"
        echo ""
        echo "1. Run full log rotation"
        echo "2. Scan for large logs"
        echo "3. Scan for old logs"
        echo "4. Show log statistics"
        echo "5. Compress old logs only"
        echo "6. Delete old logs only"
        echo ""
        echo "0. Exit to main menu"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1)
                # Full rotation
                clear
                echo "========================================"
                echo " Full Log Rotation"
                echo "========================================"
                echo ""
                
                show_log_stats
                echo ""
                find_large_logs "$MAX_SIZE_MB"
                echo ""
                find_old_logs "$RETENTION_DAYS"
                echo ""
                rotate_logs
                
                echo ""
                print_success "Log rotation completed!"
                read -p "Press Enter to continue..."
                ;;
                
            2)
                # Scan for large logs
                clear
                echo "========================================"
                echo " Scan for Large Logs"
                echo "========================================"
                echo ""
                
                find_large_logs "$MAX_SIZE_MB"
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            3)
                # Scan for old logs
                clear
                echo "========================================"
                echo " Scan for Old Logs"
                echo "========================================"
                echo ""
                
                find_old_logs "$RETENTION_DAYS"
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            4)
                # Show statistics
                clear
                echo "========================================"
                echo " Log Directory Statistics"
                echo "========================================"
                echo ""
                
                show_log_stats
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            5)
                # Compress only
                clear
                echo "========================================"
                echo " Compress Old Logs"
                echo "========================================"
                echo ""
                
                print_info "Compressing logs older than $COMPRESS_AFTER_DAYS days..."
                echo ""
                
                local compressed_count=0
                
                while IFS= read -r file; do
                    if [ -f "$file" ] && [[ "$file" != *.gz ]]; then
                        if compress_log "$file"; then
                            ((compressed_count++))
                        fi
                    fi
                done < <(find "${LOG_DIRS[@]}" -type f -name "*.log.*" -mtime +$COMPRESS_AFTER_DAYS ! -name "*.gz" 2>/dev/null)
                
                echo ""
                if [ $compressed_count -eq 0 ]; then
                    print_info "No logs to compress"
                else
                    print_success "Compressed $compressed_count log file(s)"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            6)
                # Delete only
                clear
                echo "========================================"
                echo " Delete Old Logs"
                echo "========================================"
                echo ""
                
                print_warning "This will delete logs older than $RETENTION_DAYS days!"
                read -p "Are you sure? (yes/no): " confirm
                
                if [ "$confirm" = "yes" ]; then
                    echo ""
                    print_info "Deleting old logs..."
                    echo ""
                    
                    local deleted_count=0
                    
                    while IFS= read -r file; do
                        if [ -f "$file" ]; then
                            if delete_old_log "$file"; then
                                ((deleted_count++))
                            fi
                        fi
                    done < <(find "${LOG_DIRS[@]}" -type f \( -name "*.log.*" -o -name "*.gz" \) -mtime +$RETENTION_DAYS 2>/dev/null)
                    
                    echo ""
                    if [ $deleted_count -eq 0 ]; then
                        print_info "No old logs to delete"
                    else
                        print_success "Deleted $deleted_count log file(s)"
                    fi
                else
                    print_info "Operation cancelled"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            0)
                print_success "Returning to main menu..."
                break
                ;;
                
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

#******************************************************************************
# Main - Controller for Log Rotation Script
#******************************************************************************

print_header "Log Rotation Script v1.0"

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    # Command-line mode (original functionality)
    SCAN_ONLY=false
    STATS_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dirs)
                IFS=',' read -ra LOG_DIRS <<< "$2"
                shift 2
                ;;
            -s|--size)
                MAX_SIZE_MB="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -c|--compress)
                COMPRESS_AFTER_DAYS="$2"
                shift 2
                ;;
            --scan)
                SCAN_ONLY=true
                shift
                ;;
            --stats)
                STATS_ONLY=true
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
    echo "  Directories: ${LOG_DIRS[*]}"
    echo "  Max size: ${MAX_SIZE_MB}MB"
    echo "  Retention: ${RETENTION_DAYS} days"
    echo "  Compress after: ${COMPRESS_AFTER_DAYS} days"
    echo ""

    # Stats only mode
    if [ "$STATS_ONLY" = true ]; then
        show_log_stats
        exit 0
    fi

    # Scan mode
    if [ "$SCAN_ONLY" = true ]; then
        find_large_logs "$MAX_SIZE_MB"
        echo ""
        find_old_logs "$RETENTION_DAYS"
        echo ""
        show_log_stats
        exit 0
    fi

    # Full rotation
    show_log_stats
    echo ""
    find_large_logs "$MAX_SIZE_MB"
    echo ""
    find_old_logs "$RETENTION_DAYS"
    echo ""
    rotate_logs

    print_success "Log rotation completed!"
    exit 0
else
    # Interactive mode (no arguments provided)
    check_root
    interactive_menu
    exit 0
fi