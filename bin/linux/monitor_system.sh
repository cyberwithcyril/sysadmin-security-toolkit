#!/bin/bash
################################################################################
# Script Name: monitor_system.sh
# Description: System resource monitoring with alerts
# Author: Cyril Thomas
# Date: November 5, 2025
# Version: 1.0
################################################################################

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Configuration
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=85
ALERT_LOG="/var/log/sysadmin-toolkit/alerts.log"

################################################################################
# Function: check_cpu_usage
################################################################################
check_cpu_usage() {
    print_info "Checking CPU usage..."
    
    # Get CPU usage (average over 1 second)
    local cpu_usage=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -n1 | awk '{print $2}' | cut -d'%' -f1)
    local cpu_int=${cpu_usage%.*}
    
    echo "  Current CPU usage: ${cpu_usage}%"
    
    if [ "$cpu_int" -ge "$CPU_THRESHOLD" ]; then
        print_warning "CPU usage above threshold (${CPU_THRESHOLD}%)"
        log_alert "CPU_HIGH" "usage=${cpu_usage}% threshold=${CPU_THRESHOLD}%"
        return 1
    else
        print_success "CPU usage normal"
        return 0
    fi
}

################################################################################
# Function: check_memory_usage
################################################################################
check_memory_usage() {
    print_info "Checking memory usage..."
    
    # Get memory usage
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local mem_percent=$((used * 100 / total))
    
    echo "  Current memory usage: ${mem_percent}%"
    echo "  Used: $(numfmt --to=iec-i --suffix=B $((used * 1024)))"
    echo "  Total: $(numfmt --to=iec-i --suffix=B $((total * 1024)))"
    
    if [ "$mem_percent" -ge "$MEMORY_THRESHOLD" ]; then
        print_warning "Memory usage above threshold (${MEMORY_THRESHOLD}%)"
        log_alert "MEMORY_HIGH" "usage=${mem_percent}% threshold=${MEMORY_THRESHOLD}%"
        return 1
    else
        print_success "Memory usage normal"
        return 0
    fi
}

################################################################################
# Function: check_disk_usage
################################################################################
check_disk_usage() {
    print_info "Checking disk usage..."
    
    local alert_triggered=0
    
    # Check each mounted filesystem
    df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop' | while read line; do
        local filesystem=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local used=$(echo "$line" | awk '{print $3}')
        local total=$(echo "$line" | awk '{print $2}')
        
        echo "  $mountpoint: ${usage}% (${used}/${total})"
        
        if [ "$usage" -ge "$DISK_THRESHOLD" ]; then
            print_warning "Disk usage on $mountpoint above threshold (${DISK_THRESHOLD}%)"
            log_alert "DISK_HIGH" "mountpoint=$mountpoint usage=${usage}% threshold=${DISK_THRESHOLD}%"
            alert_triggered=1
        fi
    done
    
    if [ "$alert_triggered" -eq 0 ]; then
        print_success "All disk usage normal"
    fi
    
    return $alert_triggered
}

################################################################################
# Function: check_load_average
################################################################################
check_load_average() {
    print_info "Checking system load..."
    
    local load=$(uptime | awk -F'load average:' '{print $2}')
    local load_1min=$(echo "$load" | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    
    echo "  Load average: $load"
    echo "  CPU cores: $cpu_cores"
    
    # Alert if 1-min load > number of cores
    local load_int=${load_1min%.*}
    if [ "$load_int" -gt "$cpu_cores" ]; then
        print_warning "Load average high (${load_1min} on ${cpu_cores} cores)"
        log_alert "LOAD_HIGH" "load=${load_1min} cores=${cpu_cores}"
        return 1
    else
        print_success "Load average normal"
        return 0
    fi
}

################################################################################
# Function: get_top_processes
################################################################################
get_top_processes() {
    print_info "Top 5 CPU-consuming processes:"
    
    ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
        local user=$(echo "$line" | awk '{print $1}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local mem=$(echo "$line" | awk '{print $4}')
        local command=$(echo "$line" | awk '{print $11}')
        
        echo "  $command - CPU: ${cpu}% MEM: ${mem}% (user: $user)"
    done
}

################################################################################
# Function: log_alert
################################################################################
log_alert() {
    local alert_type="$1"
    local details="$2"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local alert_entry="[$timestamp] ALERT:$alert_type $details"
    
    # Create alert log directory if needed
    local log_dir=$(dirname "$ALERT_LOG")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    echo "$alert_entry" >> "$ALERT_LOG"
    log_action "SYSTEM_ALERT" "WARNING" "$details"
}

################################################################################
# Function: show_system_info
################################################################################
show_system_info() {
    print_info "System Information:"
    
    echo "  Hostname: $(hostname)"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Uptime: $(uptime -p)"
}

################################################################################
# Function: generate_report
################################################################################
generate_report() {
    print_header "System Monitoring Report"
    
    show_system_info
    echo ""
    
    local alert_count=0
    
    check_cpu_usage || ((alert_count++))
    echo ""
    
    check_memory_usage || ((alert_count++))
    echo ""
    
    check_disk_usage || ((alert_count++))
    echo ""
    
    check_load_average || ((alert_count++))
    echo ""
    
    get_top_processes
    echo ""
    
    print_header "Summary"
    if [ "$alert_count" -eq 0 ]; then
        print_success "All systems normal - no alerts triggered"
    else
        print_warning "$alert_count alert(s) triggered - check $ALERT_LOG"
    fi
    
    log_action "SYSTEM_MONITOR" "SUCCESS" "alerts=$alert_count cpu_threshold=$CPU_THRESHOLD mem_threshold=$MEMORY_THRESHOLD disk_threshold=$DISK_THRESHOLD"
}

################################################################################
# Function: show_usage
################################################################################
show_usage() {
    cat << USAGE
Usage: $0 [OPTIONS]

Options:
    --cpu-threshold PCT     CPU alert threshold (default: 80%)
    --mem-threshold PCT     Memory alert threshold (default: 85%)
    --disk-threshold PCT    Disk alert threshold (default: 85%)
    --continuous            Run continuously (check every 60 seconds)
    -h, --help              Show this help

Examples:
    $0                                  # Run single check
    $0 --cpu-threshold 90               # Use custom CPU threshold
    $0 --continuous                     # Monitor continuously

USAGE
}

################################################################################
# Main
################################################################################

print_header "System Monitoring Script v1.0"

# Parse arguments
CONTINUOUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu-threshold)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        --mem-threshold)
            MEMORY_THRESHOLD="$2"
            shift 2
            ;;
        --disk-threshold)
            DISK_THRESHOLD="$2"
            shift 2
            ;;
        --continuous)
            CONTINUOUS=true
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
echo "  CPU threshold: ${CPU_THRESHOLD}%"
echo "  Memory threshold: ${MEMORY_THRESHOLD}%"
echo "  Disk threshold: ${DISK_THRESHOLD}%"
echo "  Alert log: $ALERT_LOG"
echo ""

if [ "$CONTINUOUS" = true ]; then
    print_info "Running in continuous mode (Ctrl+C to stop)..."
    echo ""
    
    while true; do
        generate_report
        echo ""
        print_info "Waiting 60 seconds..."
        echo ""
        sleep 60
    done
else
    generate_report
fi

exit 0
