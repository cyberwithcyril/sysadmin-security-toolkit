#!/bin/bash
#******************************************************************************
# Script Name: manage_service.sh
# Description: Manage system services (start, stop, restart, status)
# Author: Cyril Thomas
# Date: November 5, 2025
# Version: 1.0
#******************************************************************************

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

#*******************************************************************************
# Function: list_services
#*******************************************************************************
#Function shows all system services 
list_services() {
    print_header "System Services"
    
    print_info "Active services:"
#Prints all system services that are active
    systemctl list-units --type=service --state=active --no-pager | grep ".service" | awk '{print "  " $1 " - " $4}'
    
    echo ""
#Prints all failed services that have a state 'failed'
    print_info "Failed services:"
    local failed=$(systemctl list-units --type=service --state=failed --no-pager | grep ".service")
    if [ -z "$failed" ]; then
        echo "  None"
    else
        echo "$failed" | awk '{print "  " $1 " - " $4}'
    fi
}

#******************************************************************************
# Function: get_service_status
#******************************************************************************
#Function gets the service status of a service 
get_service_status() {
    local service_name="$1"
    
    print_info "Service status: $service_name"

#Checks if the service is running and returns status -success/failure 
    if systemctl is-active --quiet "$service_name"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
    fi
#Checks if service is enabled - service will start at boot   
    if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_success "Service is enabled (starts at boot)"
    else
        print_warning "Service is disabled (won't start at boot)"
    fi
    
    echo ""
    echo "Detailed status:"
#Returns detailed information about the service
    systemctl status "$service_name" --no-pager -l
}

#******************************************************************************
# Function: start_service
#******************************************************************************
start_service() {
#Captures service
    local service_name="$1"
    
    print_info "Starting service: $service_name"
#Checks if service is active     
    if systemctl is-active --quiet "$service_name"; then
        print_warning "Service is already running"
        return 0
    fi
#Starts a service and returns success    
    if systemctl start "$service_name" 2>&1; then
        print_success "Service started successfully"
#Logs Service Start - 'Success'/'Failure'
        log_action "SERVICE_START" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to start service"
        log_action "SERVICE_START" "FAILURE" "service=$service_name"
        return 1
    fi
}

#*******************************************************************************
# Function: stop_service
#*******************************************************************************
#Function to stop active service
stop_service() {
#Captures service    
    local service_name="$1"

    print_info "Stopping service: $service_name"

#Checks if service is running   
    if ! systemctl is-active --quiet "$service_name"; then
        print_warning "Service is already stopped"
        return 0
    fi
#Stops service and returns success/failure   
    if systemctl stop "$service_name" 2>&1; then
        print_success "Service stopped successfully"
#Logs Service Stop - Success/Failure
        log_action "SERVICE_STOP" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to stop service"
        log_action "SERVICE_STOP" "FAILURE" "service=$service_name"
        return 1
    fi
}

#*******************************************************************************
# Function: restart_service
#*******************************************************************************
#Restarts service state
restart_service() {
#Captures service
    local service_name="$1"
    
    print_info "Restarting service: $service_name"
#Stops the service and restarts    
    if systemctl restart "$service_name" 2>&1; then
        print_success "Service restarted successfully"
#Logs Service Restart - Success/Failure
        log_action "SERVICE_RESTART" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to restart service"
        log_action "SERVICE_RESTART" "FAILURE" "service=$service_name"
        return 1
    fi
}

#*******************************************************************************
# Function: enable_service
#*******************************************************************************
#Function enables service to start at boot - Service will automatically start at boot
enable_service() {
#Captures service
    local service_name="$1"
    
    print_info "Enabling service at boot: $service_name"
#Checks if service is already enabled     
    if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_warning "Service is already enabled"
        return 0
    fi
#Enables service    
    if systemctl enable "$service_name" 2>&1; then
        print_success "Service enabled at boot"
#Logs Action - Success/Failure
        log_action "SERVICE_ENABLE" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to enable service"
        log_action "SERVICE_ENABLE" "FAILURE" "service=$service_name"
        return 1
    fi
}

#******************************************************************************
# Function: disable_service
#******************************************************************************
#Function disables and enabled service that starts at boot
disable_service() {
#Captures service
    local service_name="$1"
    
    print_info "Disabling service at boot: $service_name"
#checks if service is already disabled    
    if ! systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_warning "Service is already disabled"
        return 0
    fi
#Disables serivce and return success/failure    
    if systemctl disable "$service_name" 2>&1; then
        print_success "Service disabled at boot"
#Logs Action - Success/Failure of Service
        log_action "SERVICE_DISABLE" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to disable service"
        log_action "SERVICE_DISABLE" "FAILURE" "service=$service_name"
        return 1
    fi
}

#******************************************************************************
# Function: show_service_logs
#******************************************************************************
#Displays Logs for Service -0
show_service_logs() {
    local service_name="$1"
#Captures parameter
    local lines="${2:-20}"

 #Prints logs for service from parameter   
    print_info "Recent logs for $service_name (last $lines lines):"
    echo ""
#Displays logs
    journalctl -u "$service_name" -n "$lines" --no-pager
}

#******************************************************************************
# Function: show_usage
#******************************************************************************
#Manage_Service Guide - Referencing Available Actions
show_usage() {
    cat << USAGE
Usage: $0 <action> <service> [options]

Actions:
    list                    List all services
    status <service>        Show service status
    start <service>         Start a service
    stop <service>          Stop a service
    restart <service>       Restart a service
    enable <service>        Enable service at boot
    disable <service>       Disable service at boot
    logs <service> [lines]  Show service logs (default: 20 lines)

Examples:
    $0 list                         # List all services
    $0 status ssh                   # Check SSH status
    $0 restart ssh                  # Restart SSH
    $0 enable ssh                   # Enable SSH at boot
    $0 logs ssh 50                  # Show last 50 SSH log lines

USAGE
}
#******************************************************************************
# Function: interactive_menu
#******************************************************************************
# Interactive menu for service management
interactive_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo " Linux Service Management"
        echo "========================================"
        echo ""
        echo "1. List all services"
        echo "2. Check service status"
        echo "3. Start a service"
        echo "4. Stop a service"
        echo "5. Restart a service"
        echo "6. Enable service at boot"
        echo "7. Disable service at boot"
        echo "8. View service logs"
        echo ""
        echo "0. Exit to main menu"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1)
                # List all services
                clear
                list_services
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            2)
                # Check service status
                clear
                echo ""
                read -p "Enter service name (e.g., ssh, nginx): " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    echo ""
                    get_service_status "$service_name"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            3)
                # Start a service
                clear
                echo ""
                read -p "Enter service name to start: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    echo ""
                    start_service "$service_name"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            4)
                # Stop a service
                clear
                echo ""
                print_warning "Stopping a service may affect system functionality!"
                read -p "Enter service name to stop: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    read -p "Are you sure you want to stop $service_name? (yes/no): " confirm
                    if [ "$confirm" = "yes" ]; then
                        echo ""
                        stop_service "$service_name"
                    else
                        print_info "Operation cancelled"
                    fi
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            5)
                # Restart a service
                clear
                echo ""
                read -p "Enter service name to restart: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    echo ""
                    restart_service "$service_name"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            6)
                # Enable service at boot
                clear
                echo ""
                print_info "This will make the service start automatically at boot"
                read -p "Enter service name to enable: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    echo ""
                    enable_service "$service_name"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            7)
                # Disable service at boot
                clear
                echo ""
                print_info "This will prevent the service from starting at boot"
                read -p "Enter service name to disable: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    echo ""
                    disable_service "$service_name"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
                
            8)
                # View service logs
                clear
                echo ""
                read -p "Enter service name: " service_name
                
                if [ -z "$service_name" ]; then
                    print_error "Service name is required"
                else
                    read -p "Number of lines to show (default: 20): " lines
                    if [ -z "$lines" ]; then
                        lines=20
                    fi
                    echo ""
                    show_service_logs "$service_name" "$lines"
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

#******************************************************************************
# Main- Controller
#******************************************************************************

print_header "Service Management Script v1.0"

# Validate privileges
check_root

# Check if running with arguments (command-line mode)
if [ $# -gt 0 ]; then
    # Command-line mode (original functionality)
    ACTION="${1:-}"
    SERVICE="${2:-}"
    OPTION="${3:-}"

    # Check if action is provided
    if [ -z "$ACTION" ]; then
        print_error "No action specified"
        show_usage
        exit 1
    fi

    case "$ACTION" in
        list)
            list_services
            ;;
        status)
            # Check if service name is provided
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            get_service_status "$SERVICE"
            ;;
        start)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            start_service "$SERVICE"
            ;;
        stop)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            stop_service "$SERVICE"
            ;;
        restart)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            restart_service "$SERVICE"
            ;;
        enable)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            enable_service "$SERVICE"
            ;;
        disable)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            disable_service "$SERVICE"
            ;;
        logs)
            if [ -z "$SERVICE" ]; then
                print_error "Service name required"
                exit 1
            fi
            show_service_logs "$SERVICE" "${OPTION:-20}"
            ;;
        *)
            print_error "Unknown action: $ACTION"
            show_usage
            exit 1
            ;;
    esac

    exit 0
else
    # Interactive mode (no arguments provided)
    interactive_menu
    exit 0
fi
