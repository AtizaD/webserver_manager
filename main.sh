#!/bin/bash

# VPS Management Suite - Main Launcher (Fixed)
# Simple, reliable VPS management with proper subprocess handling
# Author: VPS Manager
# Version: 2.1

set -euo pipefail

# =============================================================================
# CONSTANTS AND CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="/opt/vps_manager"
readonly LOG_FILE="$SCRIPT_DIR/logs/main.log"
readonly CONFIG_FILE="$SCRIPT_DIR/config/main.conf"

# Repository configuration
readonly SCRIPT_BASE_URL="https://raw.githubusercontent.com/AtizaD/webserver_manager/main"
readonly SERVER_SCRIPT="server.sh"
readonly DOMAIN_SCRIPT="domain.sh"

# UI Configuration
readonly TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Unicode symbols
readonly CHECKMARK="✓"
readonly CROSS="✗"
readonly BULLET="•"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Enhanced logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Print functions
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
    echo -e "${GRAY}ℹ $1${NC}"
}

# Simple confirmation
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    local response
    
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

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges"
        print_info "Please run: sudo $SCRIPT_NAME"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        OS=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
        VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        print_error "Unsupported OS: $OS"
        exit 1
    fi
    
    log_message "INFO" "Detected OS: $OS $VERSION_ID"
    echo "$OS $VERSION_ID"
}

get_server_ip() {
    local ip
    ip=$(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
    echo "$ip"
}

get_system_info() {
    local server_ip hostname uptime_info
    
    server_ip=$(get_server_ip)
    hostname=$(hostname)
    uptime_info=$(uptime -p 2>/dev/null || uptime)
    
    cat << EOF
Server IP: $server_ip
Hostname: $hostname
Uptime: $uptime_info
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

check_scripts() {
    [[ -f "$SERVER_SCRIPT" ]] && [[ -f "$DOMAIN_SCRIPT" ]]
}

download_script() {
    local script_name="$1"
    local url="$2"
    
    print_status "Downloading $script_name..."
    
    if curl -fsSL "$url" -o "$script_name" 2>/dev/null; then
        chmod +x "$script_name"
        local version=$(get_script_version "$script_name")
        print_success "$script_name downloaded successfully (v$version)"
        log_message "INFO" "$script_name downloaded from $url"
        return 0
    else
        print_error "Failed to download $script_name"
        return 1
    fi
}

install_scripts() {
    print_header "Installing VPS Management Scripts"
    
    mkdir -p "$SCRIPT_DIR"
    
    # Download server.sh
    if ! download_script "$SERVER_SCRIPT" "$SCRIPT_BASE_URL/$SERVER_SCRIPT"; then
        print_error "Failed to download server management script"
        return 1
    fi
    
    # Download domain.sh
    if ! download_script "$DOMAIN_SCRIPT" "$SCRIPT_BASE_URL/$DOMAIN_SCRIPT"; then
        print_error "Failed to download domain management script"
        return 1
    fi
    
    print_success "All scripts installed successfully"
    return 0
}

# =============================================================================
# SERVICE STATUS
# =============================================================================

check_service_status() {
    local service="$1"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    elif command -v "$service" &> /dev/null || dpkg -l | grep -q "^ii.*$service"; then
        echo -e "${YELLOW}Stopped${NC}"
    else
        echo -e "${GRAY}Not installed${NC}"
    fi
}

display_system_status() {
    local os_info server_ip
    
    print_header "System Status Overview"
    
    os_info=$(detect_os)
    server_ip=$(get_server_ip)
    
    print_section "System Information"
    echo "OS: $os_info"
    echo "Server IP: $server_ip"
    echo "Hostname: $(hostname)"
    
    print_section "Services Status"
    printf "%-15s %s\n" "Service" "Status"
    printf "%-15s %s\n" "-------" "------"
    printf "%-15s %s\n" "Apache" "$(check_service_status apache2)"
    printf "%-15s %s\n" "Nginx" "$(check_service_status nginx)"
    printf "%-15s %s\n" "MySQL" "$(check_service_status mysql)"
    printf "%-15s %s\n" "MariaDB" "$(check_service_status mariadb)"
    printf "%-15s %s\n" "PostgreSQL" "$(check_service_status postgresql)"
    
    if command -v php &> /dev/null; then
        local php_version=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        printf "%-15s %s\n" "PHP" "v$php_version"
    else
        printf "%-15s %s\n" "PHP" "Not installed"
    fi
    
    print_section "Script Information"
    printf "%-15s %s\n" "Main script:" "v$SCRIPT_VERSION"
    printf "%-15s %s\n" "Server script:" "v$(get_script_version "$SERVER_SCRIPT")"
    printf "%-15s %s\n" "Domain script:" "v$(get_script_version "$DOMAIN_SCRIPT")"
    
    print_section "System Resources"
    echo "Memory Usage:"
    free -h | head -2
    echo
    echo "Disk Usage:"
    df -h / | tail -1
}

# =============================================================================
# MAIN INTERFACE
# =============================================================================

display_banner() {
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
    
    echo -e "${YELLOW}${BOLD}                    Professional VPS Management Suite v$SCRIPT_VERSION${NC}"
    echo -e "${GRAY}                          Ubuntu/Debian Server Management${NC}"
    echo
}

show_status_line() {
    local os_info server_ip
    
    os_info=$(detect_os)
    server_ip=$(get_server_ip)
    
    echo -e "${BLUE}${BOLD}System:${NC} $os_info  ${BLUE}${BOLD}IP:${NC} $server_ip"
    
    # Service status line
    local apache_status nginx_status db_status
    apache_status=$(check_service_status apache2)
    nginx_status=$(check_service_status nginx)
    
    # Determine database status
    if [[ "$(check_service_status mysql)" == *"Running"* ]]; then
        db_status="${GREEN}MySQL${NC}"
    elif [[ "$(check_service_status mariadb)" == *"Running"* ]]; then
        db_status="${GREEN}MariaDB${NC}"
    elif [[ "$(check_service_status postgresql)" == *"Running"* ]]; then
        db_status="${GREEN}PostgreSQL${NC}"
    else
        db_status="${GRAY}None${NC}"
    fi
    
    echo -e "${BLUE}${BOLD}Services:${NC} Apache: $apache_status  Nginx: $nginx_status  Database: $db_status"
}

launch_script() {
    local script_name="$1"
    local script_path="./$script_name"
    
    if [[ -f "$script_path" ]]; then
        print_status "Launching $script_name..."
        echo
        
        # Use exec to replace current process with the target script
        # This gives the target script full terminal control
        exec bash "$script_path"
    else
        print_error "$script_name not found"
        if confirm_action "Download $script_name?"; then
            install_scripts
            if [[ -f "$script_path" ]]; then
                exec bash "$script_path"
            fi
        fi
    fi
}

quick_setup() {
    print_header "Quick Setup Wizard"
    
    echo -e "${WHITE}Choose your preferred stack:${NC}"
    echo
    echo -e "${WHITE}1.${NC} 🔥 LAMP Stack ${GRAY}(Apache + MySQL + PHP)${NC}"
    echo -e "${WHITE}2.${NC} ⚡ LEMP Stack ${GRAY}(Nginx + MySQL + PHP)${NC}"
    echo -e "${WHITE}3.${NC} 🔙 Back to Main Menu"
    echo
    
    local choice
    read -p "$(echo -e "${BOLD}Choose setup type [1-3]:${NC} ")" choice
    
    case $choice in
        1) 
            if [[ -f "$SERVER_SCRIPT" ]]; then
                exec bash "$SERVER_SCRIPT" --lamp
            else
                print_error "Server script not found"
            fi
            ;;
        2)
            if [[ -f "$SERVER_SCRIPT" ]]; then
                exec bash "$SERVER_SCRIPT" --lemp
            else
                print_error "Server script not found"
            fi
            ;;
        3) return ;;
        *) 
            print_error "Invalid choice"
            sleep 2
            quick_setup
            ;;
    esac
}

show_main_menu() {
    while true; do
        clear
        display_banner
        show_status_line
        
        print_section "Main Menu"
        echo -e "${WHITE}1.${NC} 🖥️  Server Manager ${GRAY}(Web server, PHP, Database, Backup)${NC}"
        echo -e "${WHITE}2.${NC} 🌐 Domain Manager ${GRAY}(Domains, SSL, Virtual hosts)${NC}"
        echo -e "${WHITE}3.${NC} ⚡ Quick Setup Wizard ${GRAY}(LAMP/LEMP automated setup)${NC}"
        echo -e "${WHITE}4.${NC} 📊 System Status ${GRAY}(Detailed system information)${NC}"
        echo -e "${WHITE}5.${NC} 🔧 System Tools ${GRAY}(Updates, logs, cleanup)${NC}"
        echo -e "${WHITE}6.${NC} ❌ Exit"
        echo
        
        local choice
        read -p "$(echo -e "${BOLD}Choose option [1-6]:${NC} ")" choice
        
        case $choice in
            1) launch_script "$SERVER_SCRIPT" ;;
            2) launch_script "$DOMAIN_SCRIPT" ;;
            3) quick_setup ;;
            4) display_system_status; echo; read -p "Press Enter to continue..." ;;
            5) system_tools_menu ;;
            6) 
                print_success "Thank you for using VPS Management Suite!"
                exit 0
                ;;
            *) 
                print_error "Invalid choice. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

system_tools_menu() {
    while true; do
        print_header "System Tools"
        
        echo -e "${WHITE}1.${NC} 🔄 Update Scripts"
        echo -e "${WHITE}2.${NC} 📋 View Logs"
        echo -e "${WHITE}3.${NC} 🧹 System Cleanup"
        echo -e "${WHITE}4.${NC} 📊 Show Script Versions"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        local choice
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) 
                print_status "Updating scripts..."
                install_scripts
                echo; read -p "Press Enter to continue..."
                ;;
            2) 
                print_section "Recent Logs"
                if [[ -f "$LOG_FILE" ]]; then
                    tail -20 "$LOG_FILE"
                else
                    echo "No logs found"
                fi
                echo; read -p "Press Enter to continue..."
                ;;
            3)
                print_status "Cleaning up system..."
                apt autoremove -y >/dev/null 2>&1 || true
                apt autoclean >/dev/null 2>&1 || true
                print_success "System cleanup completed"
                echo; read -p "Press Enter to continue..."
                ;;
            4)
                print_section "Script Versions"
                echo "Main script: v$SCRIPT_VERSION"
                echo "Server script: v$(get_script_version "$SERVER_SCRIPT")"
                echo "Domain script: v$(get_script_version "$DOMAIN_SCRIPT")"
                echo; read -p "Press Enter to continue..."
                ;;
            5) break ;;
            *) 
                print_error "Invalid choice"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# INITIALIZATION
# =============================================================================

initialize_environment() {
    mkdir -p "$SCRIPT_DIR"/{logs,config,backups}
    chmod 755 "$SCRIPT_DIR"
    chmod 755 "$SCRIPT_DIR"/{logs,config,backups}
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# VPS Manager Configuration
SCRIPT_VERSION=$SCRIPT_VERSION
INSTALLATION_DATE=$(date)
REPOSITORY_URL=$SCRIPT_BASE_URL
EOF
    fi
    
    log_message "INFO" "VPS Management Suite v$SCRIPT_VERSION started"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_help() {
    cat << EOF
${BOLD}VPS Management Suite v$SCRIPT_VERSION${NC}

${BOLD}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${BOLD}OPTIONS:${NC}
    --server              Launch server manager
    --domain              Launch domain manager
    --status              Show system status
    --setup               Run quick setup wizard
    --help                Show this help

${BOLD}EXAMPLES:${NC}
    $SCRIPT_NAME                    # Interactive main menu
    $SCRIPT_NAME --server           # Direct server management
    $SCRIPT_NAME --domain           # Direct domain management
    $SCRIPT_NAME --status           # System status overview

EOF
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
            launch_script "$SERVER_SCRIPT"
            ;;
        --domain)
            check_root
            detect_os >/dev/null
            initialize_environment
            launch_script "$DOMAIN_SCRIPT"
            ;;
        --status)
            check_root
            initialize_environment
            display_system_status
            ;;
        --setup)
            check_root
            detect_os >/dev/null
            initialize_environment
            quick_setup
            ;;
        --help|help)
            show_help
            ;;
        "")
            # Interactive mode
            check_root
            detect_os >/dev/null
            initialize_environment
            
            # Check for scripts and install if missing
            if ! check_scripts; then
                print_header "Initial Setup"
                print_info "Required scripts not found. Downloading..."
                echo
                install_scripts
                echo
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
trap 'echo; print_error "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"
