#!/bin/bash
#******************************************************************************
# Script Name: monitor_system.sh
# Description: System resource monitoring with alerts
# Author: Cyril Thomas
# Date: November 5, 2025
# Version: 1.0
#*******************************************************************************

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Configuration
#CPU usage threshold
CPU_THRESHOLD=80
#Memory usage threshold
MEMORY_THRESHOLD=85
#Disk usage threshold
DISK_THRESHOLD=85
#Path where alerts are logged
ALERT_LOG="/var/log/sysadmin-toolkit/alerts.log"

#******************************************************************************
# Function: check_cpu_usage
#******************************************************************************
#Function Monitors CPU usage
check_cpu_usage() {
    print_info "Checking CPU usage..."
    
    # Get CPU usage (average over 1 second)
#Shows CPU, Memory, Processes - Ouptuts Text, 
    local cpu_usage=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -n1 | awk '{print $2}' | cut -d'%' -f1)
 #Local variable to run all commands in the pipeline and Stores in Variable
    local cpu_int=${cpu_usage%.*}
    
#Prints current CPU usage
    echo "  Current CPU usage: ${cpu_usage}%"

#Compares current CPU usage against the CPU threshold   
    if [ "$cpu_int" -ge "$CPU_THRESHOLD" ]; then

#Warning & Logs Event
        print_warning "CPU usage above threshold (${CPU_THRESHOLD}%)"
        log_alert "CPU_HIGH" "usage=${cpu_usage}% threshold=${CPU_THRESHOLD}%"
        return 1
    else
        print_success "CPU usage normal"
        return 0
    fi
}

#*******************************************************************************
# Function: check_memory_usage
#*******************************************************************************
#Function Checks Current Memory Usage using free command, Calculates percentage used,
#Displays current usage in readable format, Compares and alerts against threshold
check_memory_usage() {
    print_info "Checking memory usage..."
    
    # Get memory usage - free -shows memory usage & filters to memory line
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local mem_percent=$((used * 100 / total))
    
    echo "  Current memory usage: ${mem_percent}%"
    echo "  Used: $(numfmt --to=iec-i --suffix=B $((used * 1024)))"
    echo "  Total: $(numfmt --to=iec-i --suffix=B $((total * 1024)))"

#Checks current memory against the threshold - displays and logs warning 
    if [ "$mem_percent" -ge "$MEMORY_THRESHOLD" ]; then
        print_warning "Memory usage above threshold (${MEMORY_THRESHOLD}%)"
        log_alert "MEMORY_HIGH" "usage=${mem_percent}% threshold=${MEMORY_THRESHOLD}%"
        return 1
    else
        print_success "Memory usage normal"
        return 0
    fi
}

#******************************************************************************
# Function: check_disk_usage
#******************************************************************************
#Checks disk infor using df -h, Filters out temporary/system filesystem, Loops through each
#real disk partition, Extracts usage percentage and sizes, Checks against threshold and Logs
#alerts
check_disk_usage() {
    print_info "Checking disk usage..."

 #Sets initial alerts at 0   
    local alert_triggered=0
    
# Check each mounted filesystem using df -h [Diskfilesystem] - filters out unwanted lines
    df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop' | while read line; do
        local filesystem=$(echo "$line" | awk '{print $1}') #system
        local mountpoint=$(echo "$line" | awk '{print $6}') #location
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//') #usage percent
        local used=$(echo "$line" | awk '{print $3}') #used 
        local total=$(echo "$line" | awk '{print $2}') #total
        
        echo "  $mountpoint: ${usage}% (${used}/${total})"

#Checks usage against defined threshold - Prints warning/Logs & Increments Alert Flag  
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

#******************************************************************************
# Function: check_load_average
#******************************************************************************
#Function gets load average using uptime. Extracts 1-minute load, Gets CPU core count, 
#Compares the load to cores and alerts if load is greater than cores
#ie - Load 1.0 on 2-core = 50 % utilization
#Load 2.0 on 2-core = 100% utilization
#Load 3.0 on 2 -core = 150% utilization - System Overloaded
check_load_average() {
    print_info "Checking system load..."
    
#Retrieves Load Average
    local load=$(uptime | awk -F'load average:' '{print $2}')
#Retrieves 1 min Load
    local load_1min=$(echo "$load" | awk '{print $1}' | sed 's/,//')
#Retrieves CPU Core Count  using nproc
    local cpu_cores=$(nproc)

#Displays Load Info    
    echo "  Load average: $load"
    echo "  CPU cores: $cpu_cores"

 #Compares 1 minute load against core count
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

#******************************************************************************
# Function: get_top_processes
#******************************************************************************
#Function retrieves Top 5 CPU Consuming Processes - Identifies which processes are using the 
#most CPU

get_top_processes() {
    print_info "Top 5 CPU-consuming processes:"

#Gets all processes with ps aux - Sorts by CPU usage 
    ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
        local user=$(echo "$line" | awk '{print $1}') #user
        local cpu=$(echo "$line" | awk '{print $3}') #cpu usage
        local mem=$(echo "$line" | awk '{print $4}') #memory usage
        local command=$(echo "$line" | awk '{print $11}') #command name
        
        echo "  $command - CPU: ${cpu}% MEM: ${mem}% (user: $user)"
    done
}

#******************************************************************************
# Function: log_alert
#*******************************************************************************
#Function - records system alerts for troubleshooting
log_alert() {
    local alert_type="$1" #alert type
    local details="$2" #details
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S') #gets timestap
    local alert_entry="[$timestamp] ALERT:$alert_type $details" #Formats Alert Entry
    
#Checks if log directory exists and creates if needed
    local log_dir=$(dirname "$ALERT_LOG")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    echo "$alert_entry" >> "$ALERT_LOG"
#Logs to Main Audit Log
    log_action "SYSTEM_ALERT" "WARNING" "$details"
}

#******************************************************************************
# Function: show_system_info
#******************************************************************************
#Function displays basic system identification - hostname, OS & version, kernel version, 
#runtime.

show_system_info() {
    print_info "System Information:"

#Retrieves hostname   
    echo "  Hostname: $(hostname)"
#Retrieves OD Name & Version
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
#Retrieves Kernel Version
    echo "  Kernel: $(uname -r)"
#Retrieves Runtime
    echo "  Uptime: $(uptime -p)"
}

#******************************************************************************
# Function: generate_report
#******************************************************************************
#Function runs complete system health check and displays summary

generate_report() {
    print_header "System Monitoring Report"
    
    show_system_info
    echo ""
    
    local alert_count=0

 #Runs each function - Return 0 if normal and 1 if alert and increments counter   
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

#Compares alert counter to 0
    if [ "$alert_count" -eq 0 ]; then
        print_success "All systems normal - no alerts triggered"
    else
        print_warning "$alert_count alert(s) triggered - check $ALERT_LOG"
    fi
#Logs Reprort Execution   
    log_action "SYSTEM_MONITOR" "SUCCESS" "alerts=$alert_count cpu_threshold=$CPU_THRESHOLD mem_threshold=$MEMORY_THRESHOLD disk_threshold=$DISK_THRESHOLD"
}

#******************************************************************************
# Function: show_usage
#******************************************************************************
#Function Displays dictionary
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

#******************************************************************************
# Function: interactive_menu
#******************************************************************************
# Interactive menu for system monitoring
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux System Monitoring"
        echo "========================================"
        echo ""
        echo "Current Thresholds:"
        echo "  CPU: ${CPU_THRESHOLD}%"
        echo "  Memory: ${MEMORY_THRESHOLD}%"
        echo "  Disk: ${DISK_THRESHOLD}%"
        echo ""
        echo "1. Run single system check"
        echo "2. Start continuous monitoring (60 sec interval)"
        echo "3. Check CPU only"
        echo "4. Check memory only"
        echo "5. Check disk only"
        echo "6. View alert log"
        echo "7. Show system information"
        echo ""
        echo "0. Exit to main menu"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1)
                # Single check
                clear
                generate_report
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            2)
                # Continuous monitoring
                clear
                print_info "Starting continuous monitoring..."
                print_warning "Press Ctrl+C to stop"
                echo ""
                sleep 2
                
                while true; do
                    generate_report
                    echo ""
                    print_info "Waiting 60 seconds..."
                    echo ""
                    sleep 60
                done
                ;;
                
            3)
                # CPU only
                clear
                echo "========================================"
                echo " CPU Check"
                echo "========================================"
                echo ""
                
                show_system_info
                echo ""
                check_cpu_usage
                echo ""
                get_top_processes
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            4)
                # Memory only
                clear
                echo "========================================"
                echo " Memory Check"
                echo "========================================"
                echo ""
                
                check_memory_usage
                echo ""
                
                print_info "Memory details:"
                free -h
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            5)
                # Disk only
                clear
                echo "========================================"
                echo " Disk Check"
                echo "========================================"
                echo ""
                
                check_disk_usage
                echo ""
                
                print_info "Detailed disk usage:"
                df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop'
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            6)
                # View alert log
                clear
                echo "========================================"
                echo " Alert Log (Last 20 entries)"
                echo "========================================"
                echo ""
                
                if [ -f "$ALERT_LOG" ]; then
                    tail -20 "$ALERT_LOG"
                else
                    print_info "No alerts logged yet"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            7)
                # System info
                clear
                echo "========================================"
                echo " System Information"
                echo "========================================"
                echo ""
                
                show_system_info
                echo ""
                check_load_average
                echo ""
                get_top_processes
                
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
# Main - Controller
#******************************************************************************

print_header "System Monitoring Script v1.0"

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    # Command-line mode (original functionality)
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

    # Long term monitoring until stopped
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
else
    # Interactive mode (no arguments provided)
    check_root
    interactive_menu
    exit 0
fi