#!/bin/bash
################################################################################
# Script Name: rotate_logs.sh
# Description: Automated log rotation, compression, and cleanup
# Author: Cyril Thomas
# Date: November 4, 2025
# Version: 1.0
################################################################################

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Configuration
LOG_DIRS=("/var/log")
MAX_SIZE_MB=50
RETENTION_DAYS=30
COMPRESS_AFTER_DAYS=7

################################################################################
# Function: find_large_logs
################################################################################
find_large_logs() {
    local max_size_mb="$1"
    
    print_info "Scanning for large log files (>${max_size_mb}MB)..."
    
    local count=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local size=$(du -h "$file" | cut -f1)
            echo "  Found: $file ($size)"
            ((count++))
        fi
    done < <(find "${LOG_DIRS[@]}" -type f -name "*.log" -size +${max_size_mb}M 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_success "No large log files found"
    else
        print_warning "Found $count large log file(s)"
    fi
    
    return $count
}

################################################################################
# Function: find_old_logs
################################################################################
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
    done < <(find "${LOG_DIRS[@]}" -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.gz" \) -mtime +$retention_days 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_success "No old log files to delete"
    else
        print_warning "Found $count old log file(s)"
    fi
    
    return $count
}

################################################################################
# Function: compress_log
################################################################################
compress_log() {
    local logfile="$1"
    
    if [ ! -f "$logfile" ]; then
        return 1
    fi
    
    # Don't compress if already compressed
    if [[ "$logfile" == *.gz ]]; then
        return 0
    fi
    
    local size_before=$(du -h "$logfile" | cut -f1)
    
    if gzip -f "$logfile" 2>/dev/null; then
        local size_after=$(du -h "${logfile}.gz" | cut -f1)
        print_success "Compressed: $(basename $logfile) ($size_before → $size_after)"
        log_action "LOG_COMPRESS" "SUCCESS" "file=$(basename $logfile) size_before=$size_before size_after=$size_after"
        return 0
    else
        print_error "Failed to compress: $(basename $logfile)"
        return 1
    fi
}

################################################################################
# Function: delete_old_log
################################################################################
delete_old_log() {
    local logfile="$1"
    
    if [ ! -f "$logfile" ]; then
        return 1
    fi
    
    local size=$(du -h "$logfile" | cut -f1)
    
    if rm -f "$logfile" 2>/dev/null; then
        print_success "Deleted: $(basename $logfile) ($size)"
        log_action "LOG_DELETE" "SUCCESS" "file=$(basename $logfile) size=$size"
        return 0
    else
        print_error "Failed to delete: $(basename $logfile)"
        return 1
    fi
}

################################################################################
# Function: rotate_logs
################################################################################
rotate_logs() {
    print_info "Starting log rotation process..."
    echo ""
    
    local compressed_count=0
    local deleted_count=0
    
    # Compress logs older than COMPRESS_AFTER_DAYS
    print_info "Step 1: Compressing old uncompressed logs..."
    while IFS= read -r file; do
        if [ -f "$file" ] && [[ "$file" != *.gz ]]; then
            if compress_log "$file"; then
                ((compressed_count++))
            fi
        fi
    done < <(find "${LOG_DIRS[@]}" -type f -name "*.log.*" -mtime +$COMPRESS_AFTER_DAYS ! -name "*.gz" 2>/dev/null)
    
    if [ $compressed_count -eq 0 ]; then
        print_info "  No logs to compress"
    fi
    
    echo ""
    
    # Delete logs older than RETENTION_DAYS
    print_info "Step 2: Deleting old logs..."
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if delete_old_log "$file"; then
                ((deleted_count++))
            fi
        fi
    done < <(find "${LOG_DIRS[@]}" -type f \( -name "*.log.*" -o -name "*.gz" \) -mtime +$RETENTION_DAYS 2>/dev/null)
    
    if [ $deleted_count -eq 0 ]; then
        print_info "  No old logs to delete"
    fi
    
    echo ""
    print_header "Rotation Summary"
    echo "Compressed: $compressed_count log file(s)"
    echo "Deleted: $deleted_count log file(s)"
    
    log_action "LOG_ROTATION" "SUCCESS" "compressed=$compressed_count deleted=$deleted_count"
    
    return 0
}

################################################################################
# Function: show_log_stats
################################################################################
show_log_stats() {
    print_info "Log directory statistics:"
    echo ""
    
    for dir in "${LOG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local total_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local log_count=$(find "$dir" -type f \( -name "*.log" -o -name "*.log.*" \) 2>/dev/null | wc -l)
            local gz_count=$(find "$dir" -type f -name "*.gz" 2>/dev/null | wc -l)
            
            echo "  Directory: $dir"
            echo "    Total size: $total_size"
            echo "    Log files: $log_count"
            echo "    Compressed: $gz_count"
            echo ""
        fi
    done
}

################################################################################
# Function: show_usage
################################################################################
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

################################################################################
# Main
################################################################################

print_header "Log Rotation Script v1.0"

# Parse arguments
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
