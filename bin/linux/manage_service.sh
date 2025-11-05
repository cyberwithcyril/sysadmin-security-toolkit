#!/bin/bash
################################################################################
# Script Name: manage_service.sh
# Description: Manage system services (start, stop, restart, status)
# Author: Cyril Thomas
# Date: November 5, 2025
# Version: 1.0
################################################################################

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

################################################################################
# Function: list_services
################################################################################
list_services() {
    print_header "System Services"
    
    print_info "Active services:"
    systemctl list-units --type=service --state=active --no-pager | grep ".service" | awk '{print "  " $1 " - " $4}'
    
    echo ""
    print_info "Failed services:"
    local failed=$(systemctl list-units --type=service --state=failed --no-pager | grep ".service")
    if [ -z "$failed" ]; then
        echo "  None"
    else
        echo "$failed" | awk '{print "  " $1 " - " $4}'
    fi
}

################################################################################
# Function: get_service_status
################################################################################
get_service_status() {
    local service_name="$1"
    
    print_info "Service status: $service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
    fi
    
    if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_success "Service is enabled (starts at boot)"
    else
        print_warning "Service is disabled (won't start at boot)"
    fi
    
    echo ""
    echo "Detailed status:"
    systemctl status "$service_name" --no-pager -l
}

################################################################################
# Function: start_service
################################################################################
start_service() {
    local service_name="$1"
    
    print_info "Starting service: $service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        print_warning "Service is already running"
        return 0
    fi
    
    if systemctl start "$service_name" 2>&1; then
        print_success "Service started successfully"
        log_action "SERVICE_START" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to start service"
        log_action "SERVICE_START" "FAILURE" "service=$service_name"
        return 1
    fi
}

################################################################################
# Function: stop_service
################################################################################
stop_service() {
    local service_name="$1"
    
    print_info "Stopping service: $service_name"
    
    if ! systemctl is-active --quiet "$service_name"; then
        print_warning "Service is already stopped"
        return 0
    fi
    
    if systemctl stop "$service_name" 2>&1; then
        print_success "Service stopped successfully"
        log_action "SERVICE_STOP" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to stop service"
        log_action "SERVICE_STOP" "FAILURE" "service=$service_name"
        return 1
    fi
}

################################################################################
# Function: restart_service
################################################################################
restart_service() {
    local service_name="$1"
    
    print_info "Restarting service: $service_name"
    
    if systemctl restart "$service_name" 2>&1; then
        print_success "Service restarted successfully"
        log_action "SERVICE_RESTART" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to restart service"
        log_action "SERVICE_RESTART" "FAILURE" "service=$service_name"
        return 1
    fi
}

################################################################################
# Function: enable_service
################################################################################
enable_service() {
    local service_name="$1"
    
    print_info "Enabling service at boot: $service_name"
    
    if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_warning "Service is already enabled"
        return 0
    fi
    
    if systemctl enable "$service_name" 2>&1; then
        print_success "Service enabled at boot"
        log_action "SERVICE_ENABLE" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to enable service"
        log_action "SERVICE_ENABLE" "FAILURE" "service=$service_name"
        return 1
    fi
}

################################################################################
# Function: disable_service
################################################################################
disable_service() {
    local service_name="$1"
    
    print_info "Disabling service at boot: $service_name"
    
    if ! systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        print_warning "Service is already disabled"
        return 0
    fi
    
    if systemctl disable "$service_name" 2>&1; then
        print_success "Service disabled at boot"
        log_action "SERVICE_DISABLE" "SUCCESS" "service=$service_name"
        return 0
    else
        print_error "Failed to disable service"
        log_action "SERVICE_DISABLE" "FAILURE" "service=$service_name"
        return 1
    fi
}

################################################################################
# Function: show_service_logs
################################################################################
show_service_logs() {
    local service_name="$1"
    local lines="${2:-20}"
    
    print_info "Recent logs for $service_name (last $lines lines):"
    echo ""
    journalctl -u "$service_name" -n "$lines" --no-pager
}

################################################################################
# Function: show_usage
################################################################################
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

################################################################################
# Main
################################################################################

print_header "Service Management Script v1.0"

check_root

# Parse arguments
ACTION="${1:-}"
SERVICE="${2:-}"
OPTION="${3:-}"

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
