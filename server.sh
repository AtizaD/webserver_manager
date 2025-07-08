#!/bin/bash

# VPS Server Management Script - Production Ready
# Advanced web server, database, and system management
# Author: VPS Manager
# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONSTANTS AND CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="/opt/vps_manager"
readonly LOG_FILE="$SCRIPT_DIR/logs/server.log"
readonly BACKUP_DIR="$SCRIPT_DIR/backups"
readonly CONFIG_DIR="$SCRIPT_DIR/config"

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

# Global variables
CURRENT_WEBSERVER=""
PHP_VERSION=""
DATABASE_TYPE=""
OS=""
VERSION_ID=""

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
    if [[ -f /etc/os-release ]]; then
        OS=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
        VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        print_error "Unsupported OS: $OS"
        print_info "This script only supports Ubuntu and Debian"
        exit 1
    fi
    
    print_success "Detected OS: $OS $VERSION_ID"
    log_message "INFO" "Detected OS: $OS $VERSION_ID"
}

# Enhanced system update with progress
update_system() {
    print_section "System Update"
    
    print_status "Updating package database..."
    {
        apt update -y >/dev/null 2>&1
        echo "database_updated"
    } &
    show_spinner $! "Updating package database"
    
    print_status "Upgrading system packages..."
    {
        apt upgrade -y >/dev/null 2>&1
        echo "system_upgraded"
    } &
    show_spinner $! "Upgrading system packages"
    
    print_status "Installing essential tools..."
    {
        apt install -y curl wget git unzip software-properties-common \
                      apt-transport-https ca-certificates gnupg lsb-release \
                      htop tree vim nano ufw fail2ban >/dev/null 2>&1
        echo "tools_installed"
    } &
    show_spinner $! "Installing essential tools"
    
    print_success "System update completed successfully"
    log_message "INFO" "System packages updated and essential tools installed"
}

# =============================================================================
# WEB SERVER MANAGEMENT
# =============================================================================

# Enhanced web server detection
detect_webserver() {
    print_section "Web Server Detection"
    
    if systemctl is-active --quiet apache2 2>/dev/null; then
        CURRENT_WEBSERVER="apache"
        local version=$(apache2 -v 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        print_success "Apache is running ($version)"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        CURRENT_WEBSERVER="nginx"
        local version=$(nginx -v 2>&1 | awk -F'/' '{print $2}' || echo "unknown")
        print_success "Nginx is running ($version)"
    else
        CURRENT_WEBSERVER="none"
        print_warning "No web server is currently running"
    fi
    
    log_message "INFO" "Current web server: $CURRENT_WEBSERVER"
}

# Enhanced Apache installation
install_apache() {
    print_section "Apache Installation"
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        print_info "Apache is already installed and running"
        return 0
    fi
    
    print_status "Installing Apache2..."
    {
        apt install -y apache2 apache2-utils >/dev/null 2>&1
        echo "apache_installed"
    } &
    show_spinner $! "Installing Apache2 package"
    
    print_status "Configuring Apache modules..."
    {
        a2enmod rewrite ssl headers expires deflate >/dev/null 2>&1
        echo "modules_enabled"
    } &
    show_spinner $! "Enabling Apache modules"
    
    print_status "Configuring security settings..."
    cat > /etc/apache2/conf-available/security-enhanced.conf << 'EOF'
# Enhanced Security Configuration
ServerTokens Prod
ServerSignature Off

# Security Headers
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'"

# Hide Apache version
Header unset Server
Header always unset X-Powered-By

# Disable server-status and server-info
<Location "/server-status">
    Require all denied
</Location>
<Location "/server-info">
    Require all denied
</Location>
EOF
    
    a2enconf security-enhanced >/dev/null 2>&1
    
    print_status "Starting Apache service..."
    {
        systemctl enable apache2 >/dev/null 2>&1
        systemctl start apache2 >/dev/null 2>&1
        echo "apache_started"
    } &
    show_spinner $! "Starting Apache service"
    
    print_success "Apache2 installed and configured successfully"
    log_message "INFO" "Apache2 installed with enhanced security configuration"
}

# Enhanced Nginx installation
install_nginx() {
    print_section "Nginx Installation"
    
    if [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        print_info "Nginx is already installed and running"
        return 0
    fi
    
    print_status "Installing Nginx..."
    {
        apt install -y nginx nginx-extras >/dev/null 2>&1
        echo "nginx_installed"
    } &
    show_spinner $! "Installing Nginx package"
    
    print_status "Configuring security settings..."
    cat > /etc/nginx/snippets/security-enhanced.conf << 'EOF'
# Enhanced Security Configuration
server_tokens off;
more_set_headers "Server: ";

# Security Headers
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'" always;

# Remove X-Powered-By header
more_clear_headers "X-Powered-By";

# Disable access to hidden files
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

# Disable access to sensitive files
location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
    deny all;
    access_log off;
    log_not_found off;
}
EOF
    
    print_status "Configuring performance settings..."
    cat > /etc/nginx/snippets/performance.conf << 'EOF'
# Performance Configuration
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_proxied expired no-cache no-store private must-revalidate max-age=0;
gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

# File caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
    expires 1M;
    add_header Cache-Control "public, immutable";
}

# Client settings
client_max_body_size 64M;
client_body_timeout 12;
client_header_timeout 12;
keepalive_timeout 15;
send_timeout 10;
EOF
    
    print_status "Starting Nginx service..."
    {
        systemctl enable nginx >/dev/null 2>&1
        systemctl start nginx >/dev/null 2>&1
        echo "nginx_started"
    } &
    show_spinner $! "Starting Nginx service"
    
    print_success "Nginx installed and configured successfully"
    log_message "INFO" "Nginx installed with enhanced security and performance configuration"
}

# Enhanced web server switching
switch_to_apache() {
    print_header "Switching to Apache"
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        print_info "Apache is already the active web server"
        return 0
    fi
    
    if [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        print_status "Stopping Nginx..."
        {
            systemctl stop nginx >/dev/null 2>&1
            systemctl disable nginx >/dev/null 2>&1
            echo "nginx_stopped"
        } &
        show_spinner $! "Stopping Nginx service"
    fi
    
    if ! command -v apache2 &> /dev/null; then
        install_apache
    else
        print_status "Starting Apache..."
        {
            systemctl enable apache2 >/dev/null 2>&1
            systemctl start apache2 >/dev/null 2>&1
            echo "apache_started"
        } &
        show_spinner $! "Starting Apache service"
    fi
    
    CURRENT_WEBSERVER="apache"
    print_success "Successfully switched to Apache"
    log_message "INFO" "Web server switched to Apache"
}

# Enhanced web server switching
switch_to_nginx() {
    print_header "Switching to Nginx"
    
    if [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        print_info "Nginx is already the active web server"
        return 0
    fi
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        print_status "Stopping Apache..."
        {
            systemctl stop apache2 >/dev/null 2>&1
            systemctl disable apache2 >/dev/null 2>&1
            echo "apache_stopped"
        } &
        show_spinner $! "Stopping Apache service"
    fi
    
    if ! command -v nginx &> /dev/null; then
        install_nginx
    else
        print_status "Starting Nginx..."
        {
            systemctl enable nginx >/dev/null 2>&1
            systemctl start nginx >/dev/null 2>&1
            echo "nginx_started"
        } &
        show_spinner $! "Starting Nginx service"
    fi
    
    CURRENT_WEBSERVER="nginx"
    print_success "Successfully switched to Nginx"
    log_message "INFO" "Web server switched to Nginx"
}

# =============================================================================
# PHP MANAGEMENT
# =============================================================================

# Enhanced PHP installation with version selection
install_php() {
    print_section "PHP Installation"
    
    # Add PHP repository
    print_status "Adding PHP repository..."
    {
        add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1
        apt update >/dev/null 2>&1
        echo "repository_added"
    } &
    show_spinner $! "Adding Ondrej PHP repository"
    
    # Get available PHP versions
    local available_versions
    available_versions=$(apt-cache search php | grep -E "^php[0-9]+\.[0-9]+ " | sort -V | tail -3)
    
    if [[ -z "$available_versions" ]]; then
        PHP_VERSION="8.2"  # Fallback
        print_warning "Could not detect PHP versions, using fallback: $PHP_VERSION"
    else
        print_info "Available PHP versions:"
        echo "$available_versions" | while read -r version desc; do
            echo "  • $version"
        done
        
        # Get latest version
        PHP_VERSION=$(echo "$available_versions" | tail -1 | cut -d' ' -f1 | sed 's/php//')
        print_info "Selected PHP version: $PHP_VERSION"
    fi
    
    print_status "Installing PHP $PHP_VERSION and extensions..."
    
    # Install PHP packages with progress
    local packages=(
        "php$PHP_VERSION"
        "php$PHP_VERSION-fpm"
        "php$PHP_VERSION-mysql"
        "php$PHP_VERSION-pgsql"
        "php$PHP_VERSION-sqlite3"
        "php$PHP_VERSION-curl"
        "php$PHP_VERSION-gd"
        "php$PHP_VERSION-mbstring"
        "php$PHP_VERSION-xml"
        "php$PHP_VERSION-xmlrpc"
        "php$PHP_VERSION-zip"
        "php$PHP_VERSION-json"
        "php$PHP_VERSION-bcmath"
        "php$PHP_VERSION-intl"
        "php$PHP_VERSION-readline"
        "php$PHP_VERSION-common"
        "php$PHP_VERSION-opcache"
        "php$PHP_VERSION-imagick"
        "php$PHP_VERSION-redis"
        "php$PHP_VERSION-memcached"
    )
    
    local total=${#packages[@]}
    
    {
        apt install -y "${packages[@]}" >/dev/null 2>&1
        echo "php_installed"
    } &
    show_spinner $! "Installing PHP $PHP_VERSION with extensions"
    
    # Configure PHP
    print_status "Configuring PHP settings..."
    
    # Create optimized PHP configuration
    cat > /etc/php/$PHP_VERSION/fpm/conf.d/99-optimized.ini << 'EOF'
; Optimized PHP Configuration
memory_limit = 256M
max_execution_time = 300
max_input_time = 300
post_max_size = 64M
upload_max_filesize = 64M
max_file_uploads = 20

; Security settings
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log

; Performance settings
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 4000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1

; Session settings
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
EOF
    
    # Configure PHP-FPM
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        print_status "Configuring PHP for Apache..."
        {
            apt install -y libapache2-mod-php$PHP_VERSION >/dev/null 2>&1
            a2enmod php$PHP_VERSION >/dev/null 2>&1
            systemctl restart apache2 >/dev/null 2>&1
            echo "php_configured_apache"
        } &
        show_spinner $! "Configuring PHP with Apache"
        
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        print_status "Configuring PHP-FPM for Nginx..."
        
        # Optimize PHP-FPM pool configuration
        cat > /etc/php/$PHP_VERSION/fpm/pool.d/www.conf << 'EOF'
[www]
user = www-data
group = www-data
listen = /run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.process_idle_timeout = 10s
pm.max_requests = 500

php_admin_value[error_log] = /var/log/php-fpm.log
php_admin_flag[log_errors] = on
EOF
        
        {
            systemctl enable php$PHP_VERSION-fpm >/dev/null 2>&1
            systemctl start php$PHP_VERSION-fpm >/dev/null 2>&1
            systemctl restart nginx >/dev/null 2>&1
            echo "php_configured_nginx"
        } &
        show_spinner $! "Configuring PHP-FPM with Nginx"
    fi
    
    print_success "PHP $PHP_VERSION installed and configured successfully"
    log_message "INFO" "PHP $PHP_VERSION installed with optimized configuration"
}

# =============================================================================
# DATABASE MANAGEMENT
# =============================================================================

# Enhanced database selection with detailed info
select_database() {
    print_header "Database Selection"
    
    echo -e "${WHITE}Available database options:${NC}"
    echo
    echo -e "${WHITE}1.${NC} 🐬 MySQL ${GRAY}(Most popular, excellent performance)${NC}"
    echo -e "${WHITE}2.${NC} 🦭 MariaDB ${GRAY}(MySQL fork, enhanced features)${NC}"
    echo -e "${WHITE}3.${NC} 🐘 PostgreSQL ${GRAY}(Advanced features, JSON support)${NC}"
    echo -e "${WHITE}4.${NC} ⏭️  Skip database installation"
    echo
    
    local choice
    while true; do
        read -p "$(echo -e "${BOLD}Select database [1-4]:${NC} ")" choice
        case $choice in
            1) install_mysql; break ;;
            2) install_mariadb; break ;;
            3) install_postgresql; break ;;
            4) 
                print_info "Skipping database installation"
                log_message "INFO" "Database installation skipped by user"
                break
                ;;
            *) print_error "Invalid choice. Please select 1-4." ;;
        esac
    done
}

# Enhanced MySQL installation
install_mysql() {
    print_section "MySQL Installation"
    
    # Generate secure password
    local mysql_password=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    print_status "Preparing MySQL installation..."
    {
        # Preseed MySQL installation
        echo "mysql-server mysql-server/root_password password $mysql_password" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password $mysql_password" | debconf-set-selections
        echo "mysql_preseeded"
    } &
    show_spinner $! "Preparing MySQL configuration"
    
    print_status "Installing MySQL server..."
    {
        apt install -y mysql-server mysql-client >/dev/null 2>&1
        echo "mysql_installed"
    } &
    show_spinner $! "Installing MySQL packages"
    
    print_status "Securing MySQL installation..."
    {
        # Secure MySQL installation
        mysql -u root -p"$mysql_password" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null
        mysql -u root -p"$mysql_password" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
        mysql -u root -p"$mysql_password" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
        mysql -u root -p"$mysql_password" -e "FLUSH PRIVILEGES;" 2>/dev/null
        echo "mysql_secured"
    } &
    show_spinner $! "Securing MySQL installation"
    
    print_status "Configuring MySQL..."
    # Create optimized MySQL configuration
    cat > /etc/mysql/mysql.conf.d/99-optimized.cnf << 'EOF'
[mysqld]
# Performance settings
innodb_buffer_pool_size = 128M
innodb_log_file_size = 64M
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 1

# Security settings
bind-address = 127.0.0.1
local-infile = 0
skip-show-database

# Query cache
query_cache_type = 1
query_cache_size = 16M
query_cache_limit = 1M

# Connection settings
max_connections = 100
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600
EOF
    
    {
        systemctl enable mysql >/dev/null 2>&1
        systemctl restart mysql >/dev/null 2>&1
        echo "mysql_configured"
    } &
    show_spinner $! "Configuring MySQL service"
    
    # Save credentials securely
    cat > /root/.mysql_credentials << EOF
# MySQL Credentials - Generated $(date)
# Keep this file secure and delete after use
Host: localhost
Username: root
Password: $mysql_password
Database: mysql
EOF
    chmod 600 /root/.mysql_credentials
    
    DATABASE_TYPE="mysql"
    print_success "MySQL installed and configured successfully"
    print_info "Credentials saved to /root/.mysql_credentials"
    log_message "INFO" "MySQL installed with optimized configuration"
}

# Enhanced MariaDB installation
install_mariadb() {
    print_section "MariaDB Installation"
    
    print_status "Installing MariaDB server..."
    {
        apt install -y mariadb-server mariadb-client >/dev/null 2>&1
        echo "mariadb_installed"
    } &
    show_spinner $! "Installing MariaDB packages"
    
    print_status "Securing MariaDB installation..."
    {
        # Secure MariaDB installation
        mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null
        mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
        mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
        mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
        
        # Set root password
        local mariadb_password=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
        mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$mariadb_password');" 2>/dev/null
        echo "mariadb_secured"
    } &
    show_spinner $! "Securing MariaDB installation"
    
    print_status "Configuring MariaDB..."
    # Create optimized MariaDB configuration
    cat > /etc/mysql/mariadb.conf.d/99-optimized.cnf << 'EOF'
[mysqld]
# Performance settings
innodb_buffer_pool_size = 128M
innodb_log_file_size = 64M
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 1

# Security settings
bind-address = 127.0.0.1
local-infile = 0

# Query cache
query_cache_type = 1
query_cache_size = 16M
query_cache_limit = 1M

# Connection settings
max_connections = 100
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600
EOF
    
    {
        systemctl enable mariadb >/dev/null 2>&1
        systemctl restart mariadb >/dev/null 2>&1
        echo "mariadb_configured"
    } &
    show_spinner $! "Configuring MariaDB service"
    
    # Save credentials securely
    cat > /root/.mariadb_credentials << EOF
# MariaDB Credentials - Generated $(date)
# Keep this file secure and delete after use
Host: localhost
Username: root
Password: $mariadb_password
Database: mysql
EOF
    chmod 600 /root/.mariadb_credentials
    
    DATABASE_TYPE="mariadb"
    print_success "MariaDB installed and configured successfully"
    print_info "Credentials saved to /root/.mariadb_credentials"
    log_message "INFO" "MariaDB installed with optimized configuration"
}

# Enhanced PostgreSQL installation
install_postgresql() {
    print_section "PostgreSQL Installation"
    
    print_status "Installing PostgreSQL server..."
    {
        apt install -y postgresql postgresql-contrib postgresql-client >/dev/null 2>&1
        echo "postgresql_installed"
    } &
    show_spinner $! "Installing PostgreSQL packages"
    
    print_status "Configuring PostgreSQL..."
    
    # Generate secure password
    local postgres_password=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    {
        # Set postgres user password
        sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$postgres_password';" >/dev/null 2>&1
        
        # Create optimized PostgreSQL configuration
        local pg_version=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oE "[0-9]+\.[0-9]+" | head -1)
        local pg_config_dir="/etc/postgresql/$pg_version/main"
        
        # Update postgresql.conf
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$pg_config_dir/postgresql.conf"
        sed -i "s/#shared_buffers = 128MB/shared_buffers = 128MB/" "$pg_config_dir/postgresql.conf"
        sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 256MB/" "$pg_config_dir/postgresql.conf"
        sed -i "s/#work_mem = 4MB/work_mem = 8MB/" "$pg_config_dir/postgresql.conf"
        sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 32MB/" "$pg_config_dir/postgresql.conf"
        
        echo "postgresql_configured"
    } &
    show_spinner $! "Configuring PostgreSQL settings"
    
    {
        systemctl enable postgresql >/dev/null 2>&1
        systemctl restart postgresql >/dev/null 2>&1
        echo "postgresql_started"
    } &
    show_spinner $! "Starting PostgreSQL service"
    
    # Save credentials securely
    cat > /root/.postgresql_credentials << EOF
# PostgreSQL Credentials - Generated $(date)
# Keep this file secure and delete after use
Host: localhost
Username: postgres
Password: $postgres_password
Database: postgres
EOF
    chmod 600 /root/.postgresql_credentials
    
    DATABASE_TYPE="postgresql"
    print_success "PostgreSQL installed and configured successfully"
    print_info "Credentials saved to /root/.postgresql_credentials"
    log_message "INFO" "PostgreSQL installed with optimized configuration"
}

# =============================================================================
# FIREWALL MANAGEMENT
# =============================================================================

# Enhanced firewall configuration
configure_firewall() {
    print_header "Firewall Configuration"
    
    print_status "Installing UFW firewall..."
    {
        apt install -y ufw fail2ban >/dev/null 2>&1
        echo "firewall_installed"
    } &
    show_spinner $! "Installing firewall packages"
    
    print_status "Configuring firewall rules..."
    {
        # Reset UFW rules
        ufw --force reset >/dev/null 2>&1
        
        # Default policies
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        
        # Allow SSH (detect current port)
        local ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -1)
        if [[ -z "$ssh_port" ]]; then
            ssh_port="22"
        fi
        ufw allow "$ssh_port/tcp" comment "SSH" >/dev/null 2>&1
        
        # Allow web services
        ufw allow 80/tcp comment "HTTP" >/dev/null 2>&1
        ufw allow 443/tcp comment "HTTPS" >/dev/null 2>&1
        
        # Allow database ports (localhost only)
        if [[ "$DATABASE_TYPE" == "mysql" ]] || [[ "$DATABASE_TYPE" == "mariadb" ]]; then
            ufw allow from 127.0.0.1 to any port 3306 comment "MySQL/MariaDB" >/dev/null 2>&1
        elif [[ "$DATABASE_TYPE" == "postgresql" ]]; then
            ufw allow from 127.0.0.1 to any port 5432 comment "PostgreSQL" >/dev/null 2>&1
        fi
        
        echo "rules_configured"
    } &
    show_spinner $! "Configuring firewall rules"
    
    print_status "Configuring Fail2Ban..."
    {
        # Configure Fail2Ban
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[apache-auth]
enabled = true
filter = apache-auth
logpath = /var/log/apache*/*error.log
maxretry = 6

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 6
EOF
        
        systemctl enable fail2ban >/dev/null 2>&1
        systemctl restart fail2ban >/dev/null 2>&1
        echo "fail2ban_configured"
    } &
    show_spinner $! "Configuring Fail2Ban intrusion prevention"
    
    print_status "Enabling firewall..."
    {
        ufw --force enable >/dev/null 2>&1
        echo "firewall_enabled"
    } &
    show_spinner $! "Enabling UFW firewall"
    
    print_success "Firewall configured successfully"
    print_info "SSH port: $ssh_port, HTTP: 80, HTTPS: 443"
    log_message "INFO" "UFW firewall and Fail2Ban configured"
}

# =============================================================================
# BACKUP MANAGEMENT
# =============================================================================

# Enhanced backup system
setup_backup_system() {
    print_header "Backup System Setup"
    
    print_status "Installing backup tools..."
    {
        apt install -y rclone rsync >/dev/null 2>&1
        echo "backup_tools_installed"
    } &
    show_spinner $! "Installing backup utilities"
    
    print_section "Google Drive Configuration"
    print_info "To configure Google Drive backup, you'll need to:"
    print_info "1. Run 'rclone config' manually"
    print_info "2. Choose 'New remote' and name it 'gdrive'"
    print_info "3. Select 'Google Drive' as the storage type"
    print_info "4. Follow the authentication process"
    
    echo
    if confirm_action "Configure Google Drive backup now?"; then
        print_status "Launching rclone configuration..."
        rclone config
        
        # Test connection
        if rclone lsd gdrive: >/dev/null 2>&1; then
            print_success "Google Drive connection successful"
            log_message "INFO" "Google Drive backup configured successfully"
        else
            print_error "Google Drive connection failed"
            print_info "You can reconfigure later using 'rclone config'"
        fi
    else
        print_info "Backup system installed. Configure later with 'rclone config'"
    fi
}

# Enhanced backup creation
create_system_backup() {
    print_header "System Backup Creation"
    
    local backup_name="system_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_status "Creating backup directory..."
    mkdir -p "$backup_path"
    
    # Backup components with progress
    local components=(
        "Web server configuration"
        "PHP configuration"
        "Database dump"
        "SSL certificates"
        "System information"
    )
    
    local total=${#components[@]}
    local current=0
    
    # Backup web server configs
    ((current++))
    show_progress $current $total "Backing up web server configuration"
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        cp -r /etc/apache2 "$backup_path/" 2>/dev/null || true
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        cp -r /etc/nginx "$backup_path/" 2>/dev/null || true
    fi
    
    # Backup PHP config
    ((current++))
    show_progress $current $total "Backing up PHP configuration"
    if [[ -n "$PHP_VERSION" ]]; then
        cp -r /etc/php/$PHP_VERSION "$backup_path/" 2>/dev/null || true
    fi
    
    # Backup database
    ((current++))
    show_progress $current $total "Creating database dump"
    if [[ "$DATABASE_TYPE" == "mysql" ]]; then
        mysqldump --all-databases > "$backup_path/mysql_dump.sql" 2>/dev/null || true
    elif [[ "$DATABASE_TYPE" == "mariadb" ]]; then
        mysqldump --all-databases > "$backup_path/mariadb_dump.sql" 2>/dev/null || true
    elif [[ "$DATABASE_TYPE" == "postgresql" ]]; then
        sudo -u postgres pg_dumpall > "$backup_path/postgresql_dump.sql" 2>/dev/null || true
    fi
    
    # Backup SSL certificates
    ((current++))
    show_progress $current $total "Backing up SSL certificates"
    if [[ -d /etc/letsencrypt ]]; then
        cp -r /etc/letsencrypt "$backup_path/" 2>/dev/null || true
    fi
    
    # Create backup info file
    ((current++))
    show_progress $current $total "Creating backup metadata"
    cat > "$backup_path/backup_info.json" << EOF
{
    "backup_date": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "os": "$OS $VERSION_ID",
    "web_server": "$CURRENT_WEBSERVER",
    "php_version": "$PHP_VERSION",
    "database_type": "$DATABASE_TYPE",
    "backup_size": "$(du -sh "$backup_path" | cut -f1)",
    "script_version": "$SCRIPT_VERSION"
}
EOF
    
    print_status "Compressing backup..."
    {
        cd "$BACKUP_DIR"
        tar -czf "$backup_name.tar.gz" "$backup_name" >/dev/null 2>&1
        rm -rf "$backup_name"
        echo "backup_compressed"
    } &
    show_spinner $! "Compressing backup archive"
    
    local backup_size=$(du -sh "$BACKUP_DIR/$backup_name.tar.gz" | cut -f1)
    
    print_success "Backup created successfully"
    print_info "Backup file: $backup_name.tar.gz ($backup_size)"
    
    # Upload to Google Drive if configured
    if command -v rclone &> /dev/null && rclone lsd gdrive: >/dev/null 2>&1; then
        print_status "Uploading to Google Drive..."
        {
            rclone copy "$BACKUP_DIR/$backup_name.tar.gz" gdrive:vps_backups/ >/dev/null 2>&1
            echo "uploaded_to_gdrive"
        } &
        show_spinner $! "Uploading backup to Google Drive"
        print_success "Backup uploaded to Google Drive"
    fi
    
    log_message "INFO" "System backup created: $backup_name.tar.gz"
}

# =============================================================================
# AUTOMATED SETUPS
# =============================================================================

# LAMP stack quick setup
setup_lamp_stack() {
    print_header "LAMP Stack Quick Setup"
    
    print_info "Installing Apache, MySQL, and PHP with optimal configuration"
    echo
    
    if ! confirm_action "Install complete LAMP stack?" "Y"; then
        print_info "LAMP installation cancelled"
        return 0
    fi
    
    # Progress tracking
    local steps=(
        "System update"
        "Apache installation"
        "MySQL installation"
        "PHP installation"
        "Firewall configuration"
        "Final optimization"
    )
    
    local total=${#steps[@]}
    local current=0
    
    # Step 1: System update
    ((current++))
    show_progress $current $total "Updating system packages"
    update_system >/dev/null 2>&1
    
    # Step 2: Apache installation
    ((current++))
    show_progress $current $total "Installing Apache web server"
    switch_to_apache >/dev/null 2>&1
    
    # Step 3: MySQL installation
    ((current++))
    show_progress $current $total "Installing MySQL database"
    install_mysql >/dev/null 2>&1
    
    # Step 4: PHP installation
    ((current++))
    show_progress $current $total "Installing PHP and extensions"
    install_php >/dev/null 2>&1
    
    # Step 5: Firewall configuration
    ((current++))
    show_progress $current $total "Configuring firewall"
    configure_firewall >/dev/null 2>&1
    
    # Step 6: Final optimization
    ((current++))
    show_progress $current $total "Applying final optimizations"
    systemctl restart apache2 >/dev/null 2>&1
    
    echo
    print_success "LAMP stack installed successfully!"
    print_info "Apache + MySQL + PHP are now configured and running"
    
    log_message "INFO" "LAMP stack quick setup completed"
}

# LEMP stack quick setup
setup_lemp_stack() {
    print_header "LEMP Stack Quick Setup"
    
    print_info "Installing Nginx, MySQL, and PHP with optimal configuration"
    echo
    
    if ! confirm_action "Install complete LEMP stack?" "Y"; then
        print_info "LEMP installation cancelled"
        return 0
    fi
    
    # Progress tracking
    local steps=(
        "System update"
        "Nginx installation"
        "MySQL installation"
        "PHP installation"
        "Firewall configuration"
        "Final optimization"
    )
    
    local total=${#steps[@]}
    local current=0
    
    # Step 1: System update
    ((current++))
    show_progress $current $total "Updating system packages"
    update_system >/dev/null 2>&1
    
    # Step 2: Nginx installation
    ((current++))
    show_progress $current $total "Installing Nginx web server"
    switch_to_nginx >/dev/null 2>&1
    
    # Step 3: MySQL installation
    ((current++))
    show_progress $current $total "Installing MySQL database"
    install_mysql >/dev/null 2>&1
    
    # Step 4: PHP installation
    ((current++))
    show_progress $current $total "Installing PHP and extensions"
    install_php >/dev/null 2>&1
    
    # Step 5: Firewall configuration
    ((current++))
    show_progress $current $total "Configuring firewall"
    configure_firewall >/dev/null 2>&1
    
    # Step 6: Final optimization
    ((current++))
    show_progress $current $total "Applying final optimizations"
    systemctl restart nginx >/dev/null 2>&1
    systemctl restart php*-fpm >/dev/null 2>&1
    
    echo
    print_success "LEMP stack installed successfully!"
    print_info "Nginx + MySQL + PHP are now configured and running"
    
    log_message "INFO" "LEMP stack quick setup completed"
}

# =============================================================================
# INTERACTIVE MENUS
# =============================================================================

# Display enhanced system information
display_system_info() {
    print_header "System Information"
    
    print_section "Server Details"
    echo "OS: $OS $VERSION_ID"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')"
    echo "Server IP: $(curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unknown")"
    
    print_section "Resource Usage"
    echo "Memory Usage:"
    free -h
    echo
    echo "Disk Usage:"
    df -h /
    echo
    echo "Top Processes:"
    ps aux --sort=-%cpu | head -6
    
    print_section "Service Status"
    printf "%-15s %-10s %-15s\n" "Service" "Status" "Version"
    printf "%-15s %-10s %-15s\n" "-------" "------" "-------"
    
    # Check web servers
    if command -v apache2 &> /dev/null; then
        local status=$(systemctl is-active apache2 2>/dev/null || echo "inactive")
        local version=$(apache2 -v 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
        printf "%-15s %-10s %-15s\n" "Apache" "$status" "$version"
    fi
    
    if command -v nginx &> /dev/null; then
        local status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
        local version=$(nginx -v 2>&1 | awk -F'/' '{print $2}' || echo "unknown")
        printf "%-15s %-10s %-15s\n" "Nginx" "$status" "$version"
    fi
    
    # Check databases
    if command -v mysql &> /dev/null; then
        local status=$(systemctl is-active mysql 2>/dev/null || echo "inactive")
        local version=$(mysql --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        printf "%-15s %-10s %-15s\n" "MySQL" "$status" "$version"
    fi
    
    if command -v mariadb &> /dev/null; then
        local status=$(systemctl is-active mariadb 2>/dev/null || echo "inactive")
        local version=$(mariadb --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        printf "%-15s %-10s %-15s\n" "MariaDB" "$status" "$version"
    fi
    
    # Check PHP
    if command -v php &> /dev/null; then
        local version=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        printf "%-15s %-10s %-15s\n" "PHP" "installed" "$version"
    fi
}

# Enhanced main menu
show_main_menu() {
    local choice
    
    while true; do
        clear
        
        # Display banner
        echo -e "${CYAN}${BOLD}"
        cat << 'EOF'
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                          🖥️  VPS SERVER MANAGER                           ║
  ║                           Production Ready v2.0                             ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
        
        # Quick status
        echo -e "${BLUE}${BOLD}Current Configuration:${NC}"
        echo -e "Web Server: ${GREEN}$CURRENT_WEBSERVER${NC}  PHP: ${GREEN}$PHP_VERSION${NC}  Database: ${GREEN}$DATABASE_TYPE${NC}"
        
        print_section "Main Menu"
        echo -e "${WHITE}1.${NC} 🌐 Web Server Management ${GRAY}(Apache/Nginx switching)${NC}"
        echo -e "${WHITE}2.${NC} 🐘 PHP Management ${GRAY}(Installation and configuration)${NC}"
        echo -e "${WHITE}3.${NC} 🗄️  Database Management ${GRAY}(MySQL/MariaDB/PostgreSQL)${NC}"
        echo -e "${WHITE}4.${NC} 🔥 Quick LAMP Setup ${GRAY}(Apache + MySQL + PHP)${NC}"
        echo -e "${WHITE}5.${NC} ⚡ Quick LEMP Setup ${GRAY}(Nginx + MySQL + PHP)${NC}"
        echo -e "${WHITE}6.${NC} 🛡️  Firewall Configuration ${GRAY}(UFW + Fail2Ban)${NC}"
        echo -e "${WHITE}7.${NC} 💾 Backup Management ${GRAY}(System backup & restore)${NC}"
        echo -e "${WHITE}8.${NC} 📊 System Information ${GRAY}(Detailed system status)${NC}"
        echo -e "${WHITE}9.${NC} ❌ Exit"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-9]:${NC} ")" choice
        
        case $choice in
            1) webserver_management_menu ;;
            2) install_php; echo; read -p "Press Enter to continue..." ;;
            3) database_management_menu ;;
            4) setup_lamp_stack; echo; read -p "Press Enter to continue..." ;;
            5) setup_lemp_stack; echo; read -p "Press Enter to continue..." ;;
            6) configure_firewall; echo; read -p "Press Enter to continue..." ;;
            7) backup_management_menu ;;
            8) display_system_info; echo; read -p "Press Enter to continue..." ;;
            9) 
                print_success "Thank you for using VPS Server Manager!"
                exit 0
                ;;
            *) 
                print_error "Invalid choice. Please select 1-9."
                sleep 2
                ;;
        esac
    done
}

# Web server management submenu
webserver_management_menu() {
    local choice
    
    while true; do
        print_header "Web Server Management"
        echo -e "${BLUE}${BOLD}Current web server: ${GREEN}$CURRENT_WEBSERVER${NC}"
        echo
        
        echo -e "${WHITE}1.${NC} 🔄 Switch to Apache"
        echo -e "${WHITE}2.${NC} 🔄 Switch to Nginx"
        echo -e "${WHITE}3.${NC} 🔃 Restart Current Web Server"
        echo -e "${WHITE}4.${NC} 📊 Web Server Status"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) switch_to_apache; echo; read -p "Press Enter to continue..." ;;
            2) switch_to_nginx; echo; read -p "Press Enter to continue..." ;;
            3) 
                if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
                    print_status "Restarting Apache..."
                    systemctl restart apache2
                    print_success "Apache restarted successfully"
                elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
                    print_status "Restarting Nginx..."
                    systemctl restart nginx
                    print_success "Nginx restarted successfully"
                else
                    print_error "No web server is currently running"
                fi
                echo; read -p "Press Enter to continue..."
                ;;
            4) 
                print_section "Web Server Status"
                systemctl status apache2 nginx --no-pager 2>/dev/null || echo "No web servers found"
                echo; read -p "Press Enter to continue..."
                ;;
            5) break ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

# Database management submenu
database_management_menu() {
    local choice
    
    while true; do
        print_header "Database Management"
        echo -e "${BLUE}${BOLD}Current database: ${GREEN}$DATABASE_TYPE${NC}"
        echo
        
        echo -e "${WHITE}1.${NC} 🐬 Install MySQL"
        echo -e "${WHITE}2.${NC} 🦭 Install MariaDB"
        echo -e "${WHITE}3.${NC} 🐘 Install PostgreSQL"
        echo -e "${WHITE}4.${NC} 📊 Database Status"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) install_mysql; echo; read -p "Press Enter to continue..." ;;
            2) install_mariadb; echo; read -p "Press Enter to continue..." ;;
            3) install_postgresql; echo; read -p "Press Enter to continue..." ;;
            4) 
                print_section "Database Status"
                systemctl status mysql mariadb postgresql --no-pager 2>/dev/null || echo "No databases found"
                echo; read -p "Press Enter to continue..."
                ;;
            5) break ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

# Backup management submenu
backup_management_menu() {
    local choice
    
    while true; do
        print_header "Backup Management"
        
        echo -e "${WHITE}1.${NC} ⚙️  Setup Backup System"
        echo -e "${WHITE}2.${NC} 💾 Create System Backup"
        echo -e "${WHITE}3.${NC} 📋 List Available Backups"
        echo -e "${WHITE}4.${NC} 🔄 Restore from Backup"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) setup_backup_system; echo; read -p "Press Enter to continue..." ;;
            2) create_system_backup; echo; read -p "Press Enter to continue..." ;;
            3) 
                print_section "Available Backups"
                if [[ -d "$BACKUP_DIR" ]]; then
                    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
                else
                    echo "No backup directory found"
                fi
                echo; read -p "Press Enter to continue..."
                ;;
            4) 
                print_warning "Restore functionality requires manual verification"
                print_info "Please check backup files manually before restoring"
                echo; read -p "Press Enter to continue..."
                ;;
            5) break ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Main function
main() {
    print_header "VPS Server Management - Production Ready v$SCRIPT_VERSION"
    
    # Initial setup
    check_root
    detect_os
    
    # Create necessary directories
    mkdir -p "$SCRIPT_DIR"/{logs,backups,config}
    
    # Log startup
    log_message "INFO" "VPS Server Manager started (v$SCRIPT_VERSION)"
    
    # Update system
    if confirm_action "Update system packages before starting?" "Y"; then
        update_system
    fi
    
    # Detect current setup
    detect_webserver
    
    # Start main menu
    show_main_menu
}

# Command line argument handling
if [[ $# -gt 0 ]]; then
    case $1 in
        --lamp)
            check_root
            detect_os
            mkdir -p "$SCRIPT_DIR"/{logs,backups,config}
            log_message "INFO" "LAMP stack quick setup started"
            setup_lamp_stack
            exit 0
            ;;
        --lemp)
            check_root
            detect_os
            mkdir -p "$SCRIPT_DIR"/{logs,backups,config}
            log_message "INFO" "LEMP stack quick setup started"
            setup_lemp_stack
            exit 0
            ;;
        --help)
            echo "VPS Server Management Script v$SCRIPT_VERSION"
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --lamp     Quick LAMP stack setup (Apache + MySQL + PHP)"
            echo "  --lemp     Quick LEMP stack setup (Nginx + MySQL + PHP)"
            echo "  --help     Show this help message"
            echo
            echo "Run without arguments for interactive mode"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_info "Use --help for usage information"
            exit 1
            ;;
    esac
fi

# Trap signals for graceful shutdown
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"
