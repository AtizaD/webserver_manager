#!/bin/bash

# VPS Domain Management Script - Production Ready
# Advanced domain, SSL, and virtual host management
# Author: VPS Manager
# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONSTANTS AND CONFIGURATION
# =============================================================================

readonly VERSION="2.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="/opt/vps_manager"
readonly LOG_FILE="$SCRIPT_DIR/logs/domain.log"
readonly DOMAIN_LIST_FILE="$SCRIPT_DIR/config/domains.conf"
readonly DOMAINS_ROOT="/var/www"
readonly SERVER_SCRIPT="./server.sh"

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
SERVER_IP=""

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

# Enhanced domain validation
validate_domain() {
    local domain="$1"
    
    # Check domain format
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "Invalid domain format: $domain"
        print_info "Domain should be in format: example.com"
        return 1
    fi
    
    # Check domain length
    if [[ ${#domain} -gt 255 ]]; then
        print_error "Domain name too long: $domain"
        print_info "Domain name must be 255 characters or less"
        return 1
    fi
    
    # Check for localhost or IP addresses
    if [[ "$domain" == "localhost" ]] || [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid domain: $domain"
        print_info "Please use a valid domain name, not localhost or IP address"
        return 1
    fi
    
    print_success "Domain format is valid"
    return 0
}

# Enhanced DNS checking
check_domain_dns() {
    local domain="$1"
    local show_details="${2:-true}"
    
    if [[ "$show_details" == "true" ]]; then
        print_status "Checking DNS resolution for $domain..."
    fi
    
    # Check A record
    local ip_address
    ip_address=$(dig +short "$domain" A 2>/dev/null | head -1)
    
    if [[ -n "$ip_address" ]]; then
        if [[ "$show_details" == "true" ]]; then
            print_success "Domain resolves to: $ip_address"
            
            # Check if it points to this server
            if [[ "$ip_address" == "$SERVER_IP" ]]; then
                print_success "Domain points to this server"
            else
                print_warning "Domain points to different server ($ip_address ≠ $SERVER_IP)"
            fi
        fi
        return 0
    else
        if [[ "$show_details" == "true" ]]; then
            print_warning "Domain $domain does not resolve to any IP address"
            print_info "Make sure DNS records are configured properly"
        fi
        return 1
    fi
}

# Get server IP address
get_server_ip() {
    local ip
    ip=$(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || \
         timeout 5 curl -s https://icanhazip.com 2>/dev/null || \
         timeout 5 curl -s https://ipecho.net/plain 2>/dev/null || \
         echo "Unknown")
    
    SERVER_IP="$ip"
    echo "$ip"
}

# =============================================================================
# WEB SERVER DETECTION AND MANAGEMENT
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
    
    log_message "INFO" "Detected web server: $CURRENT_WEBSERVER"
}

# Enhanced web server installation check
ensure_webserver() {
    if [[ "$CURRENT_WEBSERVER" == "none" ]]; then
        print_warning "No web server is installed or running"
        
        echo
        echo -e "${WHITE}Available options:${NC}"
        echo -e "${WHITE}1.${NC} Install Apache (recommended for beginners)"
        echo -e "${WHITE}2.${NC} Install Nginx (recommended for performance)"
        echo -e "${WHITE}3.${NC} Run server.sh for full setup"
        echo -e "${WHITE}4.${NC} Exit and install manually"
        echo
        
        local choice
        while true; do
            read -p "$(echo -e "${BOLD}Choose option [1-4]:${NC} ")" choice
            case $choice in
                1)
                    install_apache_basic
                    break
                    ;;
                2)
                    install_nginx_basic
                    break
                    ;;
                3)
                    if [[ -f "$SERVER_SCRIPT" ]]; then
                        print_status "Launching server.sh..."
                        bash "$SERVER_SCRIPT"
                        detect_webserver
                    else
                        print_error "server.sh not found"
                        print_info "Please install a web server manually"
                        exit 1
                    fi
                    break
                    ;;
                4)
                    print_info "Please install a web server first:"
                    print_info "• Apache: apt install apache2"
                    print_info "• Nginx: apt install nginx"
                    exit 1
                    ;;
                *)
                    print_error "Invalid choice. Please select 1-4."
                    ;;
            esac
        done
    fi
}

# Basic Apache installation
install_apache_basic() {
    print_section "Basic Apache Installation"
    
    print_status "Installing Apache..."
    {
        apt update >/dev/null 2>&1
        apt install -y apache2 >/dev/null 2>&1
        systemctl enable apache2 >/dev/null 2>&1
        systemctl start apache2 >/dev/null 2>&1
        echo "apache_installed"
    } &
    show_spinner $! "Installing and starting Apache"
    
    CURRENT_WEBSERVER="apache"
    print_success "Apache installed and started"
    log_message "INFO" "Apache installed via domain manager"
}

# Basic Nginx installation
install_nginx_basic() {
    print_section "Basic Nginx Installation"
    
    print_status "Installing Nginx..."
    {
        apt update >/dev/null 2>&1
        apt install -y nginx >/dev/null 2>&1
        systemctl enable nginx >/dev/null 2>&1
        systemctl start nginx >/dev/null 2>&1
        echo "nginx_installed"
    } &
    show_spinner $! "Installing and starting Nginx"
    
    CURRENT_WEBSERVER="nginx"
    print_success "Nginx installed and started"
    log_message "INFO" "Nginx installed via domain manager"
}

# =============================================================================
# DOMAIN MANAGEMENT
# =============================================================================

# Enhanced domain tracking
add_domain_to_list() {
    local domain="$1"
    local webserver="$2"
    local ssl_status="$3"
    local document_root="$4"
    
    mkdir -p "$(dirname "$DOMAIN_LIST_FILE")"
    
    # Remove existing entry if present
    if [[ -f "$DOMAIN_LIST_FILE" ]]; then
        grep -v "^$domain:" "$DOMAIN_LIST_FILE" > "$DOMAIN_LIST_FILE.tmp" 2>/dev/null || true
        mv "$DOMAIN_LIST_FILE.tmp" "$DOMAIN_LIST_FILE"
    fi
    
    # Add new entry with enhanced information
    echo "$domain:$webserver:$ssl_status:$document_root:$(date '+%Y-%m-%d %H:%M:%S')" >> "$DOMAIN_LIST_FILE"
    log_message "INFO" "Domain $domain added to tracking list"
}

# Enhanced domain removal
remove_domain_from_list() {
    local domain="$1"
    
    if [[ -f "$DOMAIN_LIST_FILE" ]]; then
        grep -v "^$domain:" "$DOMAIN_LIST_FILE" > "$DOMAIN_LIST_FILE.tmp" 2>/dev/null || true
        mv "$DOMAIN_LIST_FILE.tmp" "$DOMAIN_LIST_FILE"
        log_message "INFO" "Domain $domain removed from tracking list"
    fi
}

# Enhanced Apache virtual host creation
create_apache_vhost() {
    local domain="$1"
    local document_root="$DOMAINS_ROOT/$domain"
    local config_file="/etc/apache2/sites-available/$domain.conf"
    
    print_section "Apache Virtual Host Creation"
    
    # Create document root
    print_status "Creating document root..."
    mkdir -p "$document_root"
    
    # Create enhanced virtual host configuration
    print_status "Creating virtual host configuration..."
    cat > "$config_file" << EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $document_root
    
    # Directory configuration
    <Directory $document_root>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Frame-Options DENY
        Header always set X-Content-Type-Options nosniff
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Referrer-Policy "strict-origin-when-cross-origin"
        
        # Performance optimizations
        <IfModule mod_expires.c>
            ExpiresActive On
            ExpiresByType text/css "access plus 1 month"
            ExpiresByType application/javascript "access plus 1 month"
            ExpiresByType image/png "access plus 1 month"
            ExpiresByType image/jpg "access plus 1 month"
            ExpiresByType image/jpeg "access plus 1 month"
            ExpiresByType image/gif "access plus 1 month"
            ExpiresByType image/ico "access plus 1 month"
            ExpiresByType image/icon "access plus 1 month"
            ExpiresByType image/x-icon "access plus 1 month"
        </IfModule>
    </Directory>
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/$domain-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain-access.log combined
    
    # Hide sensitive files
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>
    
    <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
        Require all denied
    </FilesMatch>
</VirtualHost>
EOF
    
    # Enable site and reload Apache
    print_status "Enabling virtual host..."
    {
        a2ensite "$domain.conf" >/dev/null 2>&1
        a2enmod headers expires >/dev/null 2>&1
        systemctl reload apache2 >/dev/null 2>&1
        echo "vhost_enabled"
    } &
    show_spinner $! "Enabling virtual host and reloading Apache"
    
    create_default_website "$domain" "$document_root"
    
    print_success "Apache virtual host created successfully"
    log_message "INFO" "Apache virtual host created for $domain"
}

# Enhanced Nginx server block creation
create_nginx_vhost() {
    local domain="$1"
    local document_root="$DOMAINS_ROOT/$domain"
    local config_file="/etc/nginx/sites-available/$domain"
    
    print_section "Nginx Server Block Creation"
    
    # Create document root
    print_status "Creating document root..."
    mkdir -p "$document_root"
    
    # Create enhanced server block configuration
    print_status "Creating server block configuration..."
    cat > "$config_file" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $document_root;
    index index.html index.htm index.php;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Main location block
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Static file caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt|svg|woff|woff2|ttf|eot)$ {
        expires 1M;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to sensitive files
    location ~* \.(htaccess|htpasswd|ini|log|sh|inc|bak)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Logging
    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;
}
EOF
    
    # Enable site and reload Nginx
    print_status "Enabling server block..."
    {
        ln -sf "$config_file" "/etc/nginx/sites-enabled/"
        nginx -t >/dev/null 2>&1
        systemctl reload nginx >/dev/null 2>&1
        echo "server_block_enabled"
    } &
    show_spinner $! "Enabling server block and reloading Nginx"
    
    create_default_website "$domain" "$document_root"
    
    print_success "Nginx server block created successfully"
    log_message "INFO" "Nginx server block created for $domain"
}

# Enhanced default website creation
create_default_website() {
    local domain="$1"
    local document_root="$2"
    
    print_status "Creating default website..."
    
    # Create a beautiful default page
    cat > "$document_root/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to $domain</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .container {
            text-align: center;
            max-width: 600px;
            padding: 2rem;
        }
        
        .logo {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
        
        h1 {
            font-size: 2.5rem;
            margin-bottom: 1rem;
            font-weight: 300;
        }
        
        .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }
        
        .info-box {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 1.5rem;
            margin: 2rem 0;
            backdrop-filter: blur(10px);
        }
        
        .status {
            display: inline-block;
            background: #4CAF50;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.9rem;
            margin-bottom: 1rem;
        }
        
        .footer {
            margin-top: 2rem;
            opacity: 0.7;
            font-size: 0.9rem;
        }
        
        .server-info {
            margin-top: 1rem;
            font-size: 0.8rem;
            opacity: 0.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>Welcome to $domain</h1>
        <p class="subtitle">Your website is now configured and ready to use!</p>
        
        <div class="info-box">
            <div class="status">✓ Domain Active</div>
            <p>Your domain is successfully configured with the VPS Manager.</p>
            <p>You can now upload your website files to replace this page.</p>
        </div>
        
        <div class="info-box">
            <h3>📁 Document Root</h3>
            <p><code>$document_root</code></p>
            <br>
            <h3>🔧 Web Server</h3>
            <p>$CURRENT_WEBSERVER</p>
        </div>
        
        <div class="footer">
            <p>Powered by VPS Manager v2.0</p>
            <div class="server-info">
                Generated on $(date)<br>
                Server IP: $SERVER_IP
            </div>
        </div>
    </div>
</body>
</html>
EOF
    
    # Create a simple PHP info page
    cat > "$document_root/info.php" << 'EOF'
<?php
// PHP Info Page - Remove this file in production
if (php_sapi_name() !== 'cli') {
    echo "<div style='background: #f0f8ff; padding: 20px; border-left: 4px solid #007cba; margin: 20px;'>";
    echo "<h3>🐘 PHP Information</h3>";
    echo "<p>PHP Version: " . phpversion() . "</p>";
    echo "<p>Server Software: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
    echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
    echo "</div>";
}
?>
EOF
    
    # Set proper permissions
    chown -R www-data:www-data "$document_root"
    chmod -R 755 "$document_root"
    
    print_success "Default website created"
}

# Enhanced domain addition
add_domain() {
    print_header "Add New Domain"
    
    local domain
    echo -e "${WHITE}Domain Configuration${NC}"
    echo -e "${GRAY}${DIM}Enter the domain name you want to add (e.g., example.com)${NC}"
    echo
    
    while true; do
        read -p "$(echo -e "${BOLD}Domain name:${NC} ")" domain
        
        if [[ -z "$domain" ]]; then
            print_error "Domain name cannot be empty"
            continue
        fi
        
        if validate_domain "$domain"; then
            break
        fi
    done
    
    # Check if domain already exists
    if [[ "$CURRENT_WEBSERVER" == "apache" ]] && [[ -f "/etc/apache2/sites-available/$domain.conf" ]]; then
        print_error "Domain $domain already exists for Apache"
        return 1
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]] && [[ -f "/etc/nginx/sites-available/$domain" ]]; then
        print_error "Domain $domain already exists for Nginx"
        return 1
    fi
    
    # DNS check (optional)
    echo
    if confirm_action "Check DNS resolution for $domain?"; then
        check_domain_dns "$domain"
    fi
    
    # Create virtual host based on web server
    echo
    print_status "Creating virtual host for $domain..."
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        create_apache_vhost "$domain"
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        create_nginx_vhost "$domain"
    fi
    
    # Add to domain tracking
    add_domain_to_list "$domain" "$CURRENT_WEBSERVER" "false" "$DOMAINS_ROOT/$domain"
    
    print_success "Domain $domain added successfully"
    print_info "Document root: $DOMAINS_ROOT/$domain"
    print_info "You can now upload your website files to this directory"
    
    # Ask about SSL
    echo
    if confirm_action "Install SSL certificate for $domain?"; then
        install_ssl_certificate "$domain"
    fi
    
    log_message "INFO" "Domain $domain added successfully"
}

# Enhanced domain removal
remove_domain() {
    print_header "Remove Domain"
    
    # Show available domains
    if ! list_domains_simple; then
        print_warning "No domains configured yet"
        return 0
    fi
    
    echo
    local domain
    read -p "$(echo -e "${BOLD}Enter domain name to remove:${NC} ")" domain
    
    if [[ -z "$domain" ]]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    # Confirmation with details
    echo
    print_warning "This will remove the following:"
    echo "  • Virtual host configuration"
    echo "  • SSL certificate (if present)"
    echo "  • Optionally: website files"
    echo
    
    if ! confirm_action "Are you sure you want to remove $domain?"; then
        print_info "Operation cancelled"
        return 0
    fi
    
    # Remove virtual host configuration
    print_status "Removing virtual host configuration..."
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        if [[ -f "/etc/apache2/sites-available/$domain.conf" ]]; then
            {
                a2dissite "$domain.conf" >/dev/null 2>&1
                rm -f "/etc/apache2/sites-available/$domain.conf"
                systemctl reload apache2 >/dev/null 2>&1
                echo "apache_config_removed"
            } &
            show_spinner $! "Removing Apache virtual host"
        fi
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        if [[ -f "/etc/nginx/sites-available/$domain" ]]; then
            {
                rm -f "/etc/nginx/sites-enabled/$domain"
                rm -f "/etc/nginx/sites-available/$domain"
                systemctl reload nginx >/dev/null 2>&1
                echo "nginx_config_removed"
            } &
            show_spinner $! "Removing Nginx server block"
        fi
    fi
    
    # Remove SSL certificate
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        print_status "Removing SSL certificate..."
        {
            certbot delete --cert-name "$domain" --non-interactive >/dev/null 2>&1
            echo "ssl_removed"
        } &
        show_spinner $! "Removing SSL certificate"
    fi
    
    # Ask about document root
    echo
    if confirm_action "Remove website files in $DOMAINS_ROOT/$domain?"; then
        print_status "Removing website files..."
        {
            rm -rf "$DOMAINS_ROOT/$domain"
            echo "files_removed"
        } &
        show_spinner $! "Removing website files"
        print_success "Website files removed"
    else
        print_info "Website files preserved in $DOMAINS_ROOT/$domain"
    fi
    
    # Remove from tracking
    remove_domain_from_list "$domain"
    
    print_success "Domain $domain removed successfully"
    log_message "INFO" "Domain $domain removed"
}

# Enhanced domain listing (simple)
list_domains_simple() {
    if [[ ! -f "$DOMAIN_LIST_FILE" ]]; then
        return 1
    fi
    
    print_info "Configured domains:"
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        local ssl_indicator=""
        if [[ "$ssl_status" == "true" ]]; then
            ssl_indicator=" ${GREEN}[SSL]${NC}"
        fi
        echo "  ${BULLET} $domain$ssl_indicator"
    done < "$DOMAIN_LIST_FILE"
    
    return 0
}

# Enhanced domain listing (detailed)
list_domains_detailed() {
    print_header "Domain Overview"
    
    if [[ ! -f "$DOMAIN_LIST_FILE" ]]; then
        print_warning "No domains configured yet"
        return 0
    fi
    
    # Count domains
    local domain_count=$(wc -l < "$DOMAIN_LIST_FILE")
    print_info "Total domains: $domain_count"
    
    echo
    printf "%-25s %-10s %-8s %-10s %-20s %s\n" "Domain" "Server" "SSL" "Status" "Added" "Document Root"
    printf "%-25s %-10s %-8s %-10s %-20s %s\n" "------" "------" "---" "------" "-----" "-------------"
    
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        # Check domain accessibility
        local status="Unknown"
        local status_color="$GRAY"
        
        if curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null | grep -q "200"; then
            status="Active"
            status_color="$GREEN"
        elif curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null | grep -q "000"; then
            status="Unreachable"
            status_color="$RED"
        else
            status="Error"
            status_color="$YELLOW"
        fi
        
        # Format SSL status
        local ssl_display="No"
        local ssl_color="$GRAY"
        if [[ "$ssl_status" == "true" ]]; then
            ssl_display="Yes"
            ssl_color="$GREEN"
        fi
        
        printf "%-25s %-10s ${ssl_color}%-8s${NC} ${status_color}%-10s${NC} %-20s %s\n" \
               "$domain" "$webserver" "$ssl_display" "$status" "$date_added" "$document_root"
    done < "$DOMAIN_LIST_FILE"
}

# =============================================================================
# SSL CERTIFICATE MANAGEMENT
# =============================================================================

# Enhanced Certbot installation
install_certbot() {
    print_section "Certbot Installation"
    
    if command -v certbot &> /dev/null; then
        print_info "Certbot is already installed"
        return 0
    fi
    
    print_status "Installing Certbot..."
    
    {
        apt update >/dev/null 2>&1
        
        if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
            apt install -y certbot python3-certbot-apache >/dev/null 2>&1
        elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
            apt install -y certbot python3-certbot-nginx >/dev/null 2>&1
        fi
        
        echo "certbot_installed"
    } &
    show_spinner $! "Installing Certbot and plugins"
    
    print_success "Certbot installed successfully"
    log_message "INFO" "Certbot installed for $CURRENT_WEBSERVER"
}

# Enhanced SSL certificate installation
install_ssl_certificate() {
    local domain="$1"
    
    print_header "SSL Certificate Installation"
    
    # Install certbot if needed
    install_certbot
    
    # Pre-flight checks
    print_section "Pre-flight Checks"
    
    # Check if domain is accessible
    print_status "Checking domain accessibility..."
    if ! curl -s -o /dev/null -w "%{http_code}" "http://$domain" | grep -q "200"; then
        print_warning "Domain $domain is not accessible via HTTP"
        print_info "This may cause SSL certificate installation to fail"
        echo
        if ! confirm_action "Continue with SSL installation anyway?"; then
            return 1
        fi
    else
        print_success "Domain is accessible via HTTP"
    fi
    
    # Check DNS resolution
    print_status "Checking DNS resolution..."
    if ! check_domain_dns "$domain" "false"; then
        print_warning "DNS resolution issues detected"
        print_info "SSL certificate installation may fail"
        echo
        if ! confirm_action "Continue with SSL installation anyway?"; then
            return 1
        fi
    else
        print_success "DNS resolution is working"
    fi
    
    # Get email for Let's Encrypt
    print_section "Let's Encrypt Configuration"
    local email
    
    while true; do
        read -p "$(echo -e "${BOLD}Enter email for Let's Encrypt notifications:${NC} ")" email
        
        if [[ -z "$email" ]]; then
            print_error "Email cannot be empty"
            continue
        fi
        
        if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Invalid email format"
        fi
    done
    
    # Install certificate
    print_section "Certificate Installation"
    
    local domains_arg="-d $domain -d www.$domain"
    local success=false
    
    print_status "Installing SSL certificate..."
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        {
            certbot --apache $domains_arg \
                    --email "$email" \
                    --agree-tos \
                    --non-interactive \
                    --redirect \
                    --uir >/dev/null 2>&1
            echo "ssl_installed"
        } &
        show_spinner $! "Installing SSL certificate with Apache"
        
        if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
            success=true
        fi
        
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        {
            certbot --nginx $domains_arg \
                    --email "$email" \
                    --agree-tos \
                    --non-interactive \
                    --redirect >/dev/null 2>&1
            echo "ssl_installed"
        } &
        show_spinner $! "Installing SSL certificate with Nginx"
        
        if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
            success=true
        fi
    fi
    
    if [[ "$success" == true ]]; then
        print_success "SSL certificate installed successfully"
        
        # Update domain tracking
        if [[ -f "$DOMAIN_LIST_FILE" ]]; then
            sed -i "s/^$domain:$CURRENT_WEBSERVER:false:/$domain:$CURRENT_WEBSERVER:true:/" "$DOMAIN_LIST_FILE"
        fi
        
        # Show certificate details
        print_section "Certificate Details"
        local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
        if [[ -f "$cert_path" ]]; then
            local expire_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
            local issuer=$(openssl x509 -issuer -noout -in "$cert_path" | cut -d= -f2-)
            
            print_info "Certificate issuer: $issuer"
            print_info "Certificate expires: $expire_date"
        fi
        
        print_success "HTTPS is now available at: https://$domain"
        log_message "INFO" "SSL certificate installed for $domain"
        
    else
        print_error "SSL certificate installation failed"
        print_info "Common reasons for failure:"
        print_info "• Domain doesn't point to this server ($SERVER_IP)"
        print_info "• Port 80 or 443 is blocked by firewall"
        print_info "• DNS propagation is not complete"
        print_info "• Web server is not properly configured"
        
        log_message "ERROR" "SSL certificate installation failed for $domain"
    fi
}

# Enhanced SSL certificate renewal
renew_ssl_certificates() {
    print_header "SSL Certificate Renewal"
    
    if ! command -v certbot &> /dev/null; then
        print_error "Certbot is not installed"
        return 1
    fi
    
    print_status "Checking for certificates to renew..."
    
    # Check which certificates need renewal
    local renewal_info
    renewal_info=$(certbot certificates 2>/dev/null | grep -E "(Certificate Name|Expiry Date)" || true)
    
    if [[ -z "$renewal_info" ]]; then
        print_warning "No SSL certificates found"
        return 0
    fi
    
    print_info "Found SSL certificates:"
    echo "$renewal_info"
    
    echo
    print_status "Attempting to renew certificates..."
    
    {
        if certbot renew --quiet >/dev/null 2>&1; then
            echo "renewal_success"
        else
            echo "renewal_failed"
        fi
    } &
    show_spinner $! "Renewing SSL certificates"
    
    # Check renewal results
    if [[ -f "/var/log/letsencrypt/letsencrypt.log" ]]; then
        local recent_renewals=$(grep "$(date +%Y-%m-%d)" /var/log/letsencrypt/letsencrypt.log | grep -c "renewed" || echo "0")
        
        if [[ "$recent_renewals" -gt 0 ]]; then
            print_success "$recent_renewals certificate(s) renewed successfully"
            
            # Restart web server to apply new certificates
            print_status "Reloading web server..."
            {
                systemctl reload "$CURRENT_WEBSERVER" >/dev/null 2>&1
                echo "webserver_reloaded"
            } &
            show_spinner $! "Reloading web server configuration"
            
        else
            print_info "No certificates needed renewal"
        fi
    fi
    
    log_message "INFO" "SSL certificate renewal completed"
}

# Enhanced SSL status checking
check_ssl_status() {
    print_header "SSL Certificate Status"
    
    if [[ ! -f "$DOMAIN_LIST_FILE" ]]; then
        print_warning "No domains configured"
        return 0
    fi
    
    printf "%-25s %-10s %-20s %-15s %s\n" "Domain" "SSL" "Expires" "Days Left" "Status"
    printf "%-25s %-10s %-20s %-15s %s\n" "------" "---" "-------" "---------" "------"
    
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        if [[ "$ssl_status" == "true" ]]; then
            local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
            
            if [[ -f "$cert_path" ]]; then
                local expire_date=$(openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2)
                local expire_epoch=$(date -d "$expire_date" +%s 2>/dev/null || echo "0")
                local current_epoch=$(date +%s)
                local days_left=$(( (expire_epoch - current_epoch) / 86400 ))
                
                local status="Valid"
                local status_color="$GREEN"
                
                if [[ $days_left -lt 0 ]]; then
                    status="Expired"
                    status_color="$RED"
                elif [[ $days_left -lt 30 ]]; then
                    status="Expires Soon"
                    status_color="$YELLOW"
                fi
                
                printf "%-25s %-10s %-20s %-15s ${status_color}%s${NC}\n" \
                       "$domain" "Yes" "$expire_date" "$days_left days" "$status"
            else
                printf "%-25s %-10s %-20s %-15s ${RED}%s${NC}\n" \
                       "$domain" "Yes" "Unknown" "N/A" "Cert not found"
            fi
        else
            printf "%-25s %-10s %-20s %-15s ${GRAY}%s${NC}\n" \
                   "$domain" "No" "N/A" "N/A" "No SSL"
        fi
    done < "$DOMAIN_LIST_FILE"
}

# Enhanced SSL auto-renewal setup
setup_ssl_autorenewal() {
    print_header "SSL Auto-Renewal Setup"
    
    if ! command -v certbot &> /dev/null; then
        print_error "Certbot is not installed"
        return 1
    fi
    
    print_status "Configuring automatic SSL certificate renewal..."
    
    # Create renewal script
    local renewal_script="/usr/local/bin/ssl-renew.sh"
    cat > "$renewal_script" << 'EOF'
#!/bin/bash
# SSL Certificate Auto-Renewal Script
# Generated by VPS Manager

LOG_FILE="/var/log/ssl-renewal.log"

{
    echo "=== SSL Renewal Check: $(date) ==="
    
    # Attempt renewal
    if certbot renew --quiet; then
        echo "Certificate renewal completed successfully"
        
        # Reload web servers
        for service in apache2 nginx; do
            if systemctl is-active --quiet "$service"; then
                systemctl reload "$service"
                echo "$service reloaded"
            fi
        done
    else
        echo "Certificate renewal failed"
    fi
    
    echo "=== End SSL Renewal Check ==="
    echo ""
} >> "$LOG_FILE"
EOF
    
    chmod +x "$renewal_script"
    
    # Create cron job
    local cron_job="0 12 * * * /usr/local/bin/ssl-renew.sh"
    
    print_status "Installing cron job..."
    {
        # Remove existing cron job if present
        crontab -l 2>/dev/null | grep -v "ssl-renew.sh" | crontab -
        
        # Add new cron job
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        
        echo "cron_configured"
    } &
    show_spinner $! "Configuring automatic renewal"
    
    print_success "SSL auto-renewal configured successfully"
    print_info "Certificates will be checked daily at 12:00 PM"
    print_info "Renewal logs: /var/log/ssl-renewal.log"
    
    log_message "INFO" "SSL auto-renewal configured"
}

# =============================================================================
# DOMAIN STATUS AND MONITORING
# =============================================================================

# Enhanced domain status checking
check_domain_status() {
    print_header "Domain Status Check"
    
    local domain
    read -p "$(echo -e "${BOLD}Enter domain name to check:${NC} ")" domain
    
    if [[ -z "$domain" ]]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    print_section "Domain Analysis: $domain"
    
    # DNS Resolution Check
    print_status "Checking DNS resolution..."
    local ip_address=$(dig +short "$domain" A 2>/dev/null | head -1)
    
    if [[ -n "$ip_address" ]]; then
        print_success "DNS A record: $ip_address"
        
        # Check if it points to this server
        if [[ "$ip_address" == "$SERVER_IP" ]]; then
            print_success "Domain points to this server ✓"
        else
            print_warning "Domain points to different server"
            print_info "Expected: $SERVER_IP, Found: $ip_address"
        fi
    else
        print_error "DNS resolution failed"
    fi
    
    # WWW subdomain check
    local www_ip=$(dig +short "www.$domain" A 2>/dev/null | head -1)
    if [[ -n "$www_ip" ]]; then
        print_success "WWW subdomain: $www_ip"
    else
        print_warning "WWW subdomain not configured"
    fi
    
    # HTTP/HTTPS Connectivity Check
    print_status "Checking HTTP connectivity..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null)
    local https_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null)
    
    case "$http_code" in
        200) print_success "HTTP (80): Accessible ✓" ;;
        301|302) print_success "HTTP (80): Redirecting ↗" ;;
        000) print_error "HTTP (80): Connection refused" ;;
        *) print_warning "HTTP (80): Status $http_code" ;;
    esac
    
    case "$https_code" in
        200) print_success "HTTPS (443): Accessible ✓" ;;
        301|302) print_success "HTTPS (443): Redirecting ↗" ;;
        000) print_error "HTTPS (443): Connection refused" ;;
        *) print_warning "HTTPS (443): Status $https_code" ;;
    esac
    
    # SSL Certificate Check
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        print_status "Checking SSL certificate..."
        local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
        
        if [[ -f "$cert_path" ]]; then
            local expire_date=$(openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2)
            local expire_epoch=$(date -d "$expire_date" +%s 2>/dev/null || echo "0")
            local current_epoch=$(date +%s)
            local days_left=$(( (expire_epoch - current_epoch) / 86400 ))
            
            if [[ $days_left -gt 30 ]]; then
                print_success "SSL certificate: Valid ($days_left days left)"
            elif [[ $days_left -gt 0 ]]; then
                print_warning "SSL certificate: Expires soon ($days_left days left)"
            else
                print_error "SSL certificate: Expired"
            fi
        fi
    else
        print_warning "No SSL certificate found"
    fi
    
    # Virtual Host Check
    print_status "Checking virtual host configuration..."
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        if [[ -f "/etc/apache2/sites-available/$domain.conf" ]]; then
            if [[ -f "/etc/apache2/sites-enabled/$domain.conf" ]]; then
                print_success "Apache virtual host: Active ✓"
            else
                print_warning "Apache virtual host: Disabled"
            fi
        else
            print_error "Apache virtual host: Not configured"
        fi
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        if [[ -f "/etc/nginx/sites-available/$domain" ]]; then
            if [[ -f "/etc/nginx/sites-enabled/$domain" ]]; then
                print_success "Nginx server block: Active ✓"
            else
                print_warning "Nginx server block: Disabled"
            fi
        else
            print_error "Nginx server block: Not configured"
        fi
    fi
    
    # Document Root Check
    if [[ -d "$DOMAINS_ROOT/$domain" ]]; then
        local file_count=$(find "$DOMAINS_ROOT/$domain" -type f | wc -l)
        print_success "Document root: Exists ($file_count files)"
    else
        print_warning "Document root: Not found"
    fi
    
    print_section "Recommendations"
    
    if [[ "$ip_address" != "$SERVER_IP" ]]; then
        print_info "• Update DNS A record to point to: $SERVER_IP"
    fi
    
    if [[ -z "$www_ip" ]]; then
        print_info "• Consider adding WWW subdomain DNS record"
    fi
    
    if [[ "$https_code" != "200" ]] && [[ "$https_code" != "301" ]] && [[ "$https_code" != "302" ]]; then
        print_info "• Consider installing SSL certificate for HTTPS"
    fi
}

# =============================================================================
# INTERACTIVE MENUS
# =============================================================================

# Enhanced main menu
show_main_menu() {
    local choice
    
    while true; do
        clear
        
        # Display banner
        echo -e "${CYAN}${BOLD}"
        cat << 'EOF'
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                         🌐 VPS DOMAIN MANAGER                             ║
  ║                           Production Ready v2.0                             ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
        
        # Quick status
        echo -e "${BLUE}${BOLD}Current Configuration:${NC}"
        echo -e "Web Server: ${GREEN}$CURRENT_WEBSERVER${NC}  Server IP: ${GREEN}$SERVER_IP${NC}"
        
        # Domain count
        local domain_count=0
        if [[ -f "$DOMAIN_LIST_FILE" ]]; then
            domain_count=$(wc -l < "$DOMAIN_LIST_FILE")
        fi
        echo -e "Configured Domains: ${GREEN}$domain_count${NC}"
        
        print_section "Main Menu"
        echo -e "${WHITE}1.${NC} ➕ Add New Domain ${GRAY}(Create virtual host)${NC}"
        echo -e "${WHITE}2.${NC} ➖ Remove Domain ${GRAY}(Delete virtual host)${NC}"
        echo -e "${WHITE}3.${NC} 📋 List Domains ${GRAY}(Show all domains)${NC}"
        echo -e "${WHITE}4.${NC} 🔒 SSL Management ${GRAY}(Install and manage SSL)${NC}"
        echo -e "${WHITE}5.${NC} 🔍 Domain Status ${GRAY}(Check domain health)${NC}"
        echo -e "${WHITE}6.${NC} ⚙️  System Tools ${GRAY}(Maintenance and logs)${NC}"
        echo -e "${WHITE}7.${NC} ❌ Exit"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-7]:${NC} ")" choice
        
        case $choice in
            1) add_domain; echo; read -p "Press Enter to continue..." ;;
            2) remove_domain; echo; read -p "Press Enter to continue..." ;;
            3) list_domains_detailed; echo; read -p "Press Enter to continue..." ;;
            4) ssl_management_menu ;;
            5) check_domain_status; echo; read -p "Press Enter to continue..." ;;
            6) system_tools_menu ;;
            7) 
                print_success "Thank you for using VPS Domain Manager!"
                exit 0
                ;;
            *) 
                print_error "Invalid choice. Please select 1-7."
                sleep 2
                ;;
        esac
    done
}

# SSL management submenu
ssl_management_menu() {
    local choice
    
    while true; do
        print_header "SSL Management"
        
        echo -e "${WHITE}1.${NC} 🔒 Install SSL Certificate"
        echo -e "${WHITE}2.${NC} 🔄 Renew SSL Certificates"
        echo -e "${WHITE}3.${NC} 📊 Check SSL Status"
        echo -e "${WHITE}4.${NC} ⚙️  Setup Auto-Renewal"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) 
                if list_domains_simple; then
                    echo
                    local domain
                    read -p "$(echo -e "${BOLD}Enter domain name:${NC} ")" domain
                    if [[ -n "$domain" ]] && validate_domain "$domain"; then
                        install_ssl_certificate "$domain"
                    fi
                else
                    print_warning "No domains configured. Add domains first."
                fi
                echo; read -p "Press Enter to continue..."
                ;;
            2) renew_ssl_certificates; echo; read -p "Press Enter to continue..." ;;
            3) check_ssl_status; echo; read -p "Press Enter to continue..." ;;
            4) setup_ssl_autorenewal; echo; read -p "Press Enter to continue..." ;;
            5) break ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

# System tools submenu
system_tools_menu() {
    local choice
    
    while true; do
        print_header "System Tools"
        
        echo -e "${WHITE}1.${NC} 📊 System Status"
        echo -e "${WHITE}2.${NC} 📋 View Logs"
        echo -e "${WHITE}3.${NC} 🧹 Clean Up"
        echo -e "${WHITE}4.${NC} 🔧 Web Server Control"
        echo -e "${WHITE}5.${NC} 🔙 Back to Main Menu"
        echo
        
        read -p "$(echo -e "${BOLD}Choose option [1-5]:${NC} ")" choice
        
        case $choice in
            1) 
                print_section "System Status"
                echo "Web Server: $CURRENT_WEBSERVER"
                echo "Server IP: $SERVER_IP"
                echo "Domains: $(wc -l < "$DOMAIN_LIST_FILE" 2>/dev/null || echo "0")"
                echo
                echo "Service Status:"
                systemctl status "$CURRENT_WEBSERVER" --no-pager 2>/dev/null || echo "No web server running"
                echo; read -p "Press Enter to continue..."
                ;;
            2) 
                print_section "Recent Logs"
                echo "Domain Manager Logs:"
                tail -20 "$LOG_FILE" 2>/dev/null || echo "No logs found"
                echo; read -p "Press Enter to continue..."
                ;;
            3) 
                print_status "Cleaning up temporary files..."
                find /tmp -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
                print_success "Cleanup completed"
                echo; read -p "Press Enter to continue..."
                ;;
            4) 
                print_section "Web Server Control"
                echo "Current server: $CURRENT_WEBSERVER"
                echo
                echo "1. Restart web server"
                echo "2. Check web server status"
                echo "3. Back"
                echo
                read -p "Choose option [1-3]: " web_choice
                case $web_choice in
                    1)
                        print_status "Restarting $CURRENT_WEBSERVER..."
                        systemctl restart "$CURRENT_WEBSERVER"
                        print_success "$CURRENT_WEBSERVER restarted"
                        ;;
                    2)
                        systemctl status "$CURRENT_WEBSERVER" --no-pager
                        ;;
                    3) ;;
                esac
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
    print_header "VPS Domain Management - Production Ready v$VERSION"
    
    # Initial setup
    check_root
    
    # Create necessary directories
    mkdir -p "$SCRIPT_DIR"/{logs,config}
    
    # Get server IP
    print_status "Getting server IP address..."
    get_server_ip >/dev/null
    print_success "Server IP: $SERVER_IP"
    
    # Log startup
    log_message "INFO" "VPS Domain Manager started (v$VERSION)"
    
    # Detect and ensure web server
    detect_webserver
    ensure_webserver
    
    # Start main menu
    show_main_menu
}

# Command line argument handling
if [[ $# -gt 0 ]]; then
    case $1 in
        --add)
            if [[ -n "$2" ]]; then
                domain="$2"
                check_root
                get_server_ip >/dev/null
                detect_webserver
                ensure_webserver
                
                if validate_domain "$domain"; then
                    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
                        create_apache_vhost "$domain"
                    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
                        create_nginx_vhost "$domain"
                    fi
                    add_domain_to_list "$domain" "$CURRENT_WEBSERVER" "false" "$DOMAINS_ROOT/$domain"
                    print_success "Domain $domain added successfully"
                fi
            else
                print_error "Usage: $0 --add <domain>"
            fi
            exit 0
            ;;
        --list)
            if [[ -f "$DOMAIN_LIST_FILE" ]]; then
                list_domains_detailed
            else
                print_warning "No domains configured"
            fi
            exit 0
            ;;
        --ssl)
            if [[ -n "$2" ]]; then
                domain="$2"
                check_root
                get_server_ip >/dev/null
                detect_webserver
                
                if validate_domain "$domain"; then
                    install_ssl_certificate "$domain"
                fi
            else
                print_error "Usage: $0 --ssl <domain>"
            fi
            exit 0
            ;;
        --help)
            echo "VPS Domain Management Script v$VERSION"
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --add <domain>    Add a new domain"
            echo "  --list            List all domains"
            echo "  --ssl <domain>    Install SSL for domain"
            echo "  --help            Show this help"
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
