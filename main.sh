#!/bin/bash

# VPS Management Suite - Production Ready Main Launcher
# Advanced VPS management with intelligent script management
# Author: VPS Manager
# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONSTANTS AND CONFIGURATION
# =============================================================================

readonly VERSION="2.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="/opt/vps_manager"
readonly LOG_FILE="$SCRIPT_DIR/logs/main.log"
readonly CONFIG_FILE="$SCRIPT_DIR/config/main.conf"

# Repository configuration
readonly SCRIPT_BASE_URL="https://raw.githubusercontent.com/yourusername/vps-manager/main"
readonly SERVER_SCRIPT="server.sh"
readonly DOMAIN_SCRIPT="domain.sh"

# UI Configuration
readonly TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)
readonly PROGRESS_WIDTH=50

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Unicode symbols
readonly CHECKMARK="✓"
readonly CROSS="✗"
readonly ARROW="→"
readonly BULLET="•"
readonly SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# =============================================================================
# CORE UTILITY FUNCTIONS
# =============================================================================

# Enhanced logging with levels
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${FUNCNAME[2]:-main}"
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] [$caller] $message" >> "$LOG_FILE"
}

# Print functions with enhanced formatting
print_header() {
    local title="$1"
    local width=$((TERMINAL_WIDTH - 4))
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo
    echo -e "${BLUE}$(printf '━%.0s' $(seq 1 $width))${NC}"
    echo -e "${BLUE}$(printf '%*s' $padding)${WHITE}${BOLD}$title${NC}${BLUE}$(printf '%*s' $padding)${NC}"
    echo -e "${BLUE}$(printf '━%.0s' $(seq 1 $width))${NC}"
    echo
}

print_section() {
    local title="$1"
    echo
    echo -e "${CYAN}${BOLD}$title${NC}"
    echo -e "${CYAN}$(printf '─%.0s' $(seq 1 ${#title}))${NC}"
}

print_status() {
    echo -e "${BLUE}${BULLET}${NC} $1"
}

print_success() {
    echo -e "${GREEN}${CHECKMARK}${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} ${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"
    log_message "ERROR" "$1"
}

print_info() {
    echo -e "${GRAY}${DIM}ℹ $1${NC}"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local percentage=$((current * 100 / total))
    local completed=$((current * PROGRESS_WIDTH / total))
    local remaining=$((PROGRESS_WIDTH - completed))
    
    printf "\r${BLUE}Progress:${NC} ["
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] %3d%% %s" "$percentage" "$message"
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Spinner for long operations
show_spinner() {
    local pid=$1
    local message="$2"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}${SPINNER[i]}${NC} $message"
        i=$(( (i + 1) % ${#SPINNER[@]} ))
        sleep 0.1
    done
    
    printf "\r${GREEN}${CHECKMARK}${NC} $message\n"
}

# Enhanced confirmation dialog
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    local response
    
    echo
    echo -e "${YELLOW}⚠${NC} ${BOLD}$message${NC}"
    
    if [[ "$default" == "Y" ]]; then
        read -p "Continue? [Y/n]: " response
        response=${response:-Y}
    else
        read -p "Continue? [y/N]: " response
        response=${response:-N}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Loading dialog
show_loading() {
    local message="$1"
    local duration="${2:-3}"
    local i=0
    
    while [ $i -lt $duration ]; do
        for spinner in "${SPINNER[@]}"; do
            printf "\r${BLUE}$spinner${NC} $message"
            sleep 0.1
            ((i++))
            [ $i -ge $duration ] && break
        done
    done
    
    printf "\r${GREEN}${CHECKMARK}${NC} $message\n"
}

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================

# Enhanced system checks
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges"
        print_info "Please run: sudo $SCRIPT_NAME"
        exit 1
    fi
}

detect_os() {
    local os_info
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_info="$NAME $VERSION_ID"
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    if [[ "$NAME" != *"Ubuntu"* ]] && [[ "$NAME" != *"Debian"* ]]; then
        print_error "Unsupported OS: $NAME"
        print_info "This script only supports Ubuntu and Debian"
        exit 1
    fi
    
    log_message "INFO" "Detected OS: $os_info"
    echo "$os_info"
}

get_system_info() {
    local server_ip hostname uptime load_avg memory_info disk_info
    
    server_ip=$(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
    hostname=$(hostname)
    uptime=$(uptime -p 2>/dev/null || uptime)
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
    memory_info=$(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%%)", $3/1024, $2/1024, $3*100/$2}')
    disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    
    cat << EOF
Server IP: $server_ip
Hostname: $hostname
Uptime: $uptime
Load Average: $load_avg
Memory: $memory_info
Disk: $disk_info
EOF
}

# =============================================================================
# SCRIPT MANAGEMENT
# =============================================================================

get_script_version() {
    local script_file="$1"
    
    if [[ -f "$script_file" ]]; then
        grep "^# Version:" "$script_file" 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown"
    else
        echo "not_found"
    fi
}

get_remote_version() {
    local url="$1"
    local version
    
    version=$(timeout 10 curl -fsSL "$url" 2>/dev/null | grep "^# Version:" | head -1 | awk '{print $3}' 2>/dev/null)
    echo "${version:-unknown}"
}

is_newer_version() {
    local current="$1"
    local remote="$2"
    
    [[ "$current" == "not_found" ]] && return 0
    [[ "$remote" == "unknown" ]] && return 1
    [[ "$current" == "unknown" ]] && return 0
    
    # Version comparison for semantic versioning
    local IFS='.'
    local current_parts=($current)
    local remote_parts=($remote)
    
    for i in {0..2}; do
        local c=${current_parts[i]:-0}
        local r=${remote_parts[i]:-0}
        
        if (( r > c )); then
            return 0
        elif (( r < c )); then
            return 1
        fi
    done
    
    return 1
}

download_script() {
    local script_name="$1"
    local url="$2"
    local force_download="${3:-false}"
    local current_version remote_version
    
    print_section "Script Download: $script_name"
    
    current_version=$(get_script_version "$script_name")
    
    if [[ "$force_download" == "false" ]] && [[ "$current_version" != "not_found" ]]; then
        print_status "Checking for updates..."
        
        {
            remote_version=$(get_remote_version "$url")
            sleep 1  # Simulate network delay for UX
        } &
        
        show_spinner $! "Checking remote version"
        
        if ! is_newer_version "$current_version" "$remote_version"; then
            print_success "Already up to date (v$current_version)"
            return 0
        fi
        
        print_status "Update available: ${YELLOW}v$current_version${NC} ${ARROW} ${GREEN}v$remote_version${NC}"
    fi
    
    # Create backup if file exists
    if [[ -f "$script_name" ]]; then
        print_status "Creating backup..."
        cp "$script_name" "$script_name.backup"
    fi
    
    # Download with progress
    print_status "Downloading $script_name..."
    
    {
        if curl -fsSL "$url" -o "$script_name.tmp" 2>/dev/null; then
            mv "$script_name.tmp" "$script_name"
            chmod +x "$script_name"
            echo "success"
        else
            echo "failed"
        fi
    } &
    
    show_spinner $! "Downloading from repository"
    
    if [[ -f "$script_name" ]]; then
        local new_version
        new_version=$(get_script_version "$script_name")
        print_success "Downloaded successfully (v$new_version)"
        log_message "INFO" "Downloaded $script_name v$new_version from $url"
        
        # Remove backup on success
        rm -f "$script_name.backup"
        return 0
    else
        print_error "Download failed"
        log_message "ERROR" "Failed to download $script_name from $url"
        
        # Restore backup on failure
        if [[ -f "$script_name.backup" ]]; then
            mv "$script_name.backup" "$script_name"
            print_status "Restored previous version"
        fi
        return 1
    fi
}

check_script_updates() {
    local scripts=("$SERVER_SCRIPT" "$DOMAIN_SCRIPT")
    local updates_available=false
    local update_info=()
    
    print_section "Checking for Updates"
    
    for script in "${scripts[@]}"; do
        local current remote
        current=$(get_script_version "$script")
        
        print_status "Checking $script..."
        remote=$(get_remote_version "$SCRIPT_BASE_URL/$script")
        
        if is_newer_version "$current" "$remote"; then
            updates_available=true
            update_info+=("$script: v$current → v$remote")
        fi
    done
    
    echo
    if [[ "$updates_available" == true ]]; then
        print_warning "Updates available:"
        for info in "${update_info[@]}"; do
            echo -e "  ${YELLOW}${ARROW}${NC} $info"
        done
        return 0
    else
        print_success "All scripts are up to date"
        return 1
    fi
}

install_or_update_scripts() {
    local force_install="${1:-false}"
    local scripts=("$SERVER_SCRIPT" "$DOMAIN_SCRIPT")
    local urls=("$SCRIPT_BASE_URL/$SERVER_SCRIPT" "$SCRIPT_BASE_URL/$DOMAIN_SCRIPT")
    local total=${#scripts[@]}
    
    print_header "Script Management"
    
    # Check if update is needed
    if [[ "$force_install" == "false" ]] && ! check_script_updates; then
        return 0
    fi
    
    echo
    if [[ "$force_install" == "false" ]]; then
        if ! confirm_action "Download and install updates?"; then
            print_info "Update cancelled"
            return 0
        fi
    fi
    
    # Download scripts with progress
    for i in "${!scripts[@]}"; do
        local current=$((i + 1))
        show_progress $current $total "Installing ${scripts[i]}"
        
        if ! download_script "${scripts[i]}" "${urls[i]}" "$force_install"; then
            print_error "Failed to install ${scripts[i]}"
            return 1
        fi
    done
    
    print_success "All scripts installed successfully"
    log_message "INFO" "Script installation completed"
}

# =============================================================================
# SERVICE STATUS CHECKING
# =============================================================================

check_service_status() {
    local service="$1"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo -e "${YELLOW}Stopped${NC}"
    else
        echo -e "${GRAY}Not installed${NC}"
    fi
}

get_service_info() {
    local service="$1"
    local status version
    
    status=$(check_service_status "$service")
    
    case "$service" in
        "apache2")
            version=$(apache2 -v 2>/dev/null | head -1 | awk '{print $3}' || echo "N/A")
            ;;
        "nginx")
            version=$(nginx -v 2>&1 | awk -F'/' '{print $2}' || echo "N/A")
            ;;
        "mysql")
            version=$(mysql --version 2>/dev/null | awk '{print $3}' || echo "N/A")
            ;;
        "php"*)
            version=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
            ;;
        *)
            version="N/A"
            ;;
    esac
    
    printf "%-15s %-10s %s\n" "$service" "$status" "$version"
}

# =============================================================================
# SYSTEM STATUS DISPLAY
# =============================================================================

display_system_status() {
    local os_info
    
    print_header "System Status Overview"
    
    os_info=$(detect_os)
    
    print_section "System Information"
    get_system_info
    
    print_section "Services Status"
    printf "%-15s %-10s %s\n" "Service" "Status" "Version"
    printf "%-15s %-10s %s\n" "-------" "------" "-------"
    
    get_service_info "apache2"
    get_service_info "nginx"
    get_service_info "mysql"
    get_service_info "mariadb"
    get_service_info "postgresql"
    get_service_info "php"
    
    print_section "Script Information"
    printf "%-15s %s\n" "Main script:" "v$VERSION"
    printf "%-15s %s\n" "Server script:" "v$(get_script_version "$SERVER_SCRIPT")"
    printf "%-15s %s\n" "Domain script:" "v$(get_script_version "$DOMAIN_SCRIPT")"
    
    # Check for script updates
    echo
    if check_script_updates >/dev/null 2>&1; then
        print_warning "Script updates available! Run with --update to install."
    else
        print_success "All scripts are up to date"
    fi
}

# =============================================================================
# INTERACTIVE MENUS
# =============================================================================

display_main_menu() {
    local os_info server_ip
    
    clear
    
    # Banner
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║  ██╗   ██╗██████╗ ███████╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗  ║
  ║  ██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝  ║
  ║  ██║   ██║██████╔╝███████╗    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗ ║
  ║  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║ ║
  ║   ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝ ║
  ║    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝  ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}${BOLD}                    Professional VPS Management Suite v$VERSION${NC}"
    echo -e "${GRAY}${DIM}                          Ubuntu/Debian Server Management${NC}"
    echo
    
    # Quick system info
    os_info=$(detect_os)
    server_ip=$(timeout 3 curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
    
    echo -e "${BLUE}${BOLD}System:${NC} $os_info  ${BLUE}${BOLD}IP:${NC} $server_ip"
    
    # Service status indicators
    local apache_status nginx_status db_status
    apache_status=$(check_service_status "apache2")
    nginx_status=$(check_service_status "nginx")
    
    if [[ "$(check_service_status "mysql")" == *"Running"* ]]; then
        db_status="${GREEN}MySQL${NC}"
    elif [[ "$(check_service_status "mariadb")" == *"Running"* ]]; then
        db_status="${GREEN}MariaDB${NC}"
    elif [[ "$(check_service_status "postgresql")" == *"Running"* ]]; then
        db_status="${GREEN}PostgreSQL${NC}"
    else
        db_status="${GRAY}None${NC}"
    fi
    
    echo -e "${BLUE}${BOLD}Services:${NC} Apache: $apache_status  Nginx: $nginx_status  Database: $db_status"
}

show_main_menu() {
    local choice
    
    while true; do
        display_main_menu
        
        echo
        print_section "Main Menu"
        echo -e "${WHITE}1.${NC} 🖥️  Server Manager ${GRAY}(Web server, PHP, Database, Backup)${NC}"
        echo -e "${WHITE}2.${NC} 🌐 Domain Manager ${GRAY}(Domains, SSL, Virtual hosts)${NC}"
        echo -e "${WHITE}3.${NC} ⚡ Quick Setup Wizard ${GRAY}(LAMP/LEMP automated setup)${NC}"
        echo -e "${WHITE}4.${NC} 🔧 System Tools ${GRAY}(Updates, logs, cleanup)${NC}"
        echo -e "${WHITE}5.${NC} 📊 System Status ${GRAY}(Detailed system information)${NC}"
        echo -e "${WHITE}6.${NC} ❌ Exit"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-6]:${NC} ")" choice
        
        case $choice in
            1) launch_server_manager ;;
            2) launch_domain_manager ;;
            3) show_quick_setup ;;
            4) show_system_tools ;;
            5) display_system_status; echo; read -p "Press Enter to continue..." ;;
            6) exit_application ;;
            *) 
                print_error "Invalid choice. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

show_quick_setup() {
    local choice
    
    print_header "Quick Setup Wizard"
    
    print_info "This wizard will automatically install and configure your VPS"
    echo
    
    echo -e "${WHITE}1.${NC} 🔥 LAMP Stack ${GRAY}(Apache + MySQL + PHP)${NC}"
    echo -e "${WHITE}2.${NC} ⚡ LEMP Stack ${GRAY}(Nginx + MySQL + PHP)${NC}"
    echo -e "${WHITE}3.${NC} 🛠️  Custom Setup ${GRAY}(Use individual managers)${NC}"
    echo -e "${WHITE}4.${NC} 🔙 Back to Main Menu"
    echo
    
    read -p "$(echo -e "${BOLD}Choose setup type [1-4]:${NC} ")" choice
    
    case $choice in
        1) quick_setup_lamp ;;
        2) quick_setup_lemp ;;
        3) 
            print_info "Use Server Manager and Domain Manager for custom configuration"
            sleep 2
            ;;
        4) return ;;
        *) 
            print_error "Invalid choice"
            sleep 2
            show_quick_setup
            ;;
    esac
}

quick_setup_lamp() {
    print_header "LAMP Stack Quick Setup"
    
    print_info "This will install Apache, MySQL, and PHP with optimal configuration"
    echo
    
    if ! confirm_action "Install LAMP stack?"; then
        return
    fi
    
    if [[ -f "$SERVER_SCRIPT" ]]; then
        print_status "Launching automated LAMP installation..."
        show_loading "Preparing installation" 2
        bash "$SERVER_SCRIPT" --lamp
        print_success "LAMP stack setup completed!"
    else
        print_error "Server script not found"
        if confirm_action "Download required scripts?"; then
            install_or_update_scripts true
            bash "$SERVER_SCRIPT" --lamp
        fi
    fi
    
    echo
    read -p "Press Enter to continue..."
}

quick_setup_lemp() {
    print_header "LEMP Stack Quick Setup"
    
    print_info "This will install Nginx, MySQL, and PHP with optimal configuration"
    echo
    
    if ! confirm_action "Install LEMP stack?"; then
        return
    fi
    
    if [[ -f "$SERVER_SCRIPT" ]]; then
        print_status "Launching automated LEMP installation..."
        show_loading "Preparing installation" 2
        bash "$SERVER_SCRIPT" --lemp
        print_success "LEMP stack setup completed!"
    else
        print_error "Server script not found"
        if confirm_action "Download required scripts?"; then
            install_or_update_scripts true
            bash "$SERVER_SCRIPT" --lemp
        fi
    fi
    
    echo
    read -p "Press Enter to continue..."
}

show_system_tools() {
    local choice
    
    while true; do
        print_header "System Tools"
        
        echo -e "${WHITE}1.${NC} 🔄 Check for Script Updates"
        echo -e "${WHITE}2.${NC} ⬇️  Force Reinstall Scripts"
        echo -e "${WHITE}3.${NC} 📋 View System Logs"
        echo -e "${WHITE}4.${NC} 🧹 System Cleanup"
        echo -e "${WHITE}5.${NC} 📊 Script Version Information"
        echo -e "${WHITE}6.${NC} ⚙️  System Maintenance"
        echo -e "${WHITE}7.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-7]:${NC} ")" choice
        
        case $choice in
            1) check_and_update_scripts ;;
            2) force_reinstall_scripts ;;
            3) view_system_logs ;;
            4) system_cleanup ;;
            5) show_version_info ;;
            6) system_maintenance ;;
            7) return ;;
            *) 
                print_error "Invalid choice"
                sleep 2
                ;;
        esac
    done
}

check_and_update_scripts() {
    if check_script_updates; then
        if confirm_action "Install available updates?"; then
            install_or_update_scripts false
        fi
    fi
    echo
    read -p "Press Enter to continue..."
}

force_reinstall_scripts() {
    print_warning "This will reinstall all scripts regardless of version"
    echo
    if confirm_action "Force reinstall all scripts?"; then
        install_or_update_scripts true
    fi
    echo
    read -p "Press Enter to continue..."
}

view_system_logs() {
    print_header "System Logs"
    
    print_section "Main Script Logs (Last 20 lines)"
    if [[ -f "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE" | while read -r line; do
            echo -e "${GRAY}$line${NC}"
        done
    else
        print_info "No main script logs found"
    fi
    
    print_section "Server Script Logs (Last 20 lines)"
    if [[ -f "$SCRIPT_DIR/logs/server.log" ]]; then
        tail -20 "$SCRIPT_DIR/logs/server.log" | while read -r line; do
            echo -e "${GRAY}$line${NC}"
        done
    else
        print_info "No server script logs found"
    fi
    
    print_section "Domain Script Logs (Last 20 lines)"
    if [[ -f "$SCRIPT_DIR/logs/domain.log" ]]; then
        tail -20 "$SCRIPT_DIR/logs/domain.log" | while read -r line; do
            echo -e "${GRAY}$line${NC}"
        done
    else
        print_info "No domain script logs found"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

system_cleanup() {
    print_header "System Cleanup"
    
    print_info "This will clean up temporary files and update package cache"
    echo
    
    if confirm_action "Perform system cleanup?"; then
        print_status "Cleaning package cache..."
        apt autoremove -y >/dev/null 2>&1 &
        show_spinner $! "Removing unused packages"
        
        apt autoclean >/dev/null 2>&1 &
        show_spinner $! "Cleaning package cache"
        
        print_status "Cleaning old logs..."
        find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null
        
        print_status "Cleaning temporary files..."
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        
        print_success "System cleanup completed"
        log_message "INFO" "System cleanup performed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

show_version_info() {
    print_header "Version Information"
    
    print_section "Local Script Versions"
    printf "%-20s %s\n" "Main script:" "v$VERSION"
    printf "%-20s %s\n" "Server script:" "v$(get_script_version "$SERVER_SCRIPT")"
    printf "%-20s %s\n" "Domain script:" "v$(get_script_version "$DOMAIN_SCRIPT")"
    
    print_section "Remote Script Versions"
    printf "%-20s %s\n" "Server script:" "v$(get_remote_version "$SCRIPT_BASE_URL/$SERVER_SCRIPT")"
    printf "%-20s %s\n" "Domain script:" "v$(get_remote_version "$SCRIPT_BASE_URL/$DOMAIN_SCRIPT")"
    
    echo
    read -p "Press Enter to continue..."
}

system_maintenance() {
    print_header "System Maintenance"
    
    print_info "Performing routine system maintenance..."
    echo
    
    # Update package lists
    print_status "Updating package lists..."
    apt update >/dev/null 2>&1 &
    show_spinner $! "Updating package database"
    
    # Check for system updates
    local updates
    updates=$(apt list --upgradable 2>/dev/null | wc -l)
    
    if [[ $updates -gt 1 ]]; then
        print_warning "$((updates-1)) system updates available"
        if confirm_action "Install system updates?"; then
            apt upgrade -y >/dev/null 2>&1 &
            show_spinner $! "Installing system updates"
            print_success "System updates installed"
        fi
    else
        print_success "System is up to date"
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 80 ]]; then
        print_warning "Disk usage is ${disk_usage}% - consider cleanup"
    else
        print_success "Disk usage is healthy (${disk_usage}%)"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# SCRIPT LAUNCHERS
# =============================================================================

launch_server_manager() {
    if [[ -f "$SERVER_SCRIPT" ]]; then
        print_status "Launching Server Manager..."
        show_loading "Initializing server management" 1
        bash "$SERVER_SCRIPT"
    else
        print_error "Server script not found"
        if confirm_action "Download server management script?"; then
            install_or_update_scripts true
            if [[ -f "$SERVER_SCRIPT" ]]; then
                bash "$SERVER_SCRIPT"
            fi
        fi
    fi
}

launch_domain_manager() {
    if [[ -f "$DOMAIN_SCRIPT" ]]; then
        print_status "Launching Domain Manager..."
        show_loading "Initializing domain management" 1
        bash "$DOMAIN_SCRIPT"
    else
        print_error "Domain script not found"
        if confirm_action "Download domain management script?"; then
            install_or_update_scripts true
            if [[ -f "$DOMAIN_SCRIPT" ]]; then
                bash "$DOMAIN_SCRIPT"
            fi
        fi
    fi
}

# =============================================================================
# INITIALIZATION AND SETUP
# =============================================================================

initialize_environment() {
    # Create directory structure
    mkdir -p "$SCRIPT_DIR"/{logs,config,backups}
    
    # Set proper permissions
    chmod 755 "$SCRIPT_DIR"
    chmod 755 "$SCRIPT_DIR"/{logs,config,backups}
    
    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# VPS Manager Configuration
# Generated on $(date)

SCRIPT_VERSION=$VERSION
INSTALLATION_DATE=$(date)
REPOSITORY_URL=$SCRIPT_BASE_URL
EOF
    fi
    
    # Create convenient symlinks
    ln -sf "$(pwd)/$SERVER_SCRIPT" "/usr/local/bin/vps-server" 2>/dev/null || true
    ln -sf "$(pwd)/$DOMAIN_SCRIPT" "/usr/local/bin/vps-domain" 2>/dev/null || true
    
    log_message "INFO" "Environment initialized successfully"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_help() {
    cat << EOF
${BOLD}VPS Management Suite v$VERSION${NC}

${BOLD}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${BOLD}OPTIONS:${NC}
    --server              Launch server manager directly
    --domain              Launch domain manager directly
    --status              Show detailed system status
    --update              Check and install script updates
    --check-updates       Check for available updates only
    --force-reinstall     Force reinstall all scripts
    --setup               Run quick setup wizard
    --version             Show version information
    --help                Show this help message

${BOLD}EXAMPLES:${NC}
    $SCRIPT_NAME                    # Interactive main menu
    $SCRIPT_NAME --server           # Direct server management
    $SCRIPT_NAME --domain           # Direct domain management
    $SCRIPT_NAME --status           # System status overview
    $SCRIPT_NAME --update           # Update scripts if available

${BOLD}INTERACTIVE MODE:${NC}
    Run without arguments to access the full interactive interface with:
    • Server management (Apache/Nginx, PHP, databases)
    • Domain management (virtual hosts, SSL certificates)
    • Quick setup wizards (LAMP/LEMP stacks)
    • System monitoring and maintenance tools

${BOLD}SUPPORT:${NC}
    For issues or questions, check the logs at: $LOG_FILE
    
EOF
}

exit_application() {
    print_header "Thank You!"
    
    echo -e "${CYAN}${BOLD}Thank you for using VPS Management Suite!${NC}"
    echo
    echo -e "${GRAY}${DIM}For support and updates, visit: $SCRIPT_BASE_URL${NC}"
    echo
    
    log_message "INFO" "Application exited normally"
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Handle command line arguments
    case "${1:-}" in
        --server)
            check_root
            detect_os >/dev/null
            initialize_environment
            launch_server_manager
            ;;
        --domain)
            check_root
            detect_os >/dev/null
            initialize_environment
            launch_domain_manager
            ;;
        --status)
            check_root
            initialize_environment
            display_system_status
            ;;
        --update)
            check_root
            detect_os >/dev/null
            initialize_environment
            install_or_update_scripts false
            ;;
        --check-updates)
            initialize_environment
            check_script_updates
            ;;
        --force-reinstall)
            check_root
            detect_os >/dev/null
            initialize_environment
            install_or_update_scripts true
            ;;
        --setup)
            check_root
            detect_os >/dev/null
            initialize_environment
            show_quick_setup
            ;;
        --version)
            show_version_info
            ;;
        --help|help)
            show_help
            ;;
        "")
            # Interactive mode
            check_root
            detect_os >/dev/null
            initialize_environment
            
            # Check for scripts and offer to install if missing
            if [[ ! -f "$SERVER_SCRIPT" ]] || [[ ! -f "$DOMAIN_SCRIPT" ]]; then
                print_header "Initial Setup"
                print_info "Required scripts not found. Let's download them first."
                echo
                install_or_update_scripts true
            fi
            
            show_main_menu
            ;;
        *)
            print_error "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Trap signals for graceful shutdown
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"
