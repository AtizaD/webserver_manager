#!/bin/bash

# VPS Domain Manager - Clean Version  
# Version: 2.1

# Set safer defaults - removed 'u' flag to handle unbound variables gracefully
set -eo pipefail

readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_DIR="/opt/vps_manager"
readonly LOG_FILE="$SCRIPT_DIR/logs/domain.log"
readonly DOMAIN_LIST_FILE="$SCRIPT_DIR/config/domains.conf"
readonly DOMAINS_ROOT="/var/www"
readonly SERVER_SCRIPT="./server.sh"

readonly TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

readonly CHECKMARK="✓"
readonly CROSS="✗"
readonly BULLET="•"

CURRENT_WEBSERVER=""
SERVER_IP=""

# Logging
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

print_status() { echo -e "${BLUE}${BULLET}${NC} $1"; }
print_success() { echo -e "${GREEN}${CHECKMARK}${NC} ${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠${NC} ${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"; log_message "ERROR" "$1"; }
print_info() { echo -e "${GRAY}ℹ $1${NC}"; }

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

# System checks
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "Invalid domain format: $domain"
        return 1
    fi
    
    if [[ ${#domain} -gt 255 ]]; then
        print_error "Domain name too long: $domain"
        return 1
    fi
    
    if [[ "$domain" == "localhost" ]] || [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid domain: $domain"
        return 1
    fi
    
    print_success "Domain format is valid"
    return 0
}

check_domain_dns() {
    local domain="$1"
    
    print_status "Checking DNS resolution for $domain..."
    
    local ip_address
    ip_address=$(dig +short "$domain" A 2>/dev/null | head -1)
    
    if [[ -n "$ip_address" ]]; then
        print_success "Domain resolves to: $ip_address"
        
        if [[ "$ip_address" == "$SERVER_IP" ]]; then
            print_success "Domain points to this server"
        else
            print_warning "Domain points to different server ($ip_address ≠ $SERVER_IP)"
        fi
        return 0
    else
        print_warning "Domain $domain does not resolve to any IP address"
        return 1
    fi
}

get_server_ip() {
    local ip
    ip=$(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
    SERVER_IP="$ip"
    echo "$ip"
}

# Web server detection
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

ensure_webserver() {
    if [[ "$CURRENT_WEBSERVER" == "none" ]]; then
        print_warning "No web server is installed or running"
        
        echo
        echo -e "${WHITE}Available options:${NC}"
        echo -e "${WHITE}1.${NC} Install Apache"
        echo -e "${WHITE}2.${NC} Install Nginx"
        echo -e "${WHITE}3.${NC} Exit"
        echo
        
        local choice
        read -p "Choose option [1-3]: " choice
        case $choice in
            1)
                apt update >/dev/null 2>&1
                apt install -y apache2 >/dev/null 2>&1
                systemctl enable apache2 >/dev/null 2>&1
                systemctl start apache2 >/dev/null 2>&1
                CURRENT_WEBSERVER="apache"
                print_success "Apache installed and started"
                ;;
            2)
                apt update >/dev/null 2>&1
                apt install -y nginx >/dev/null 2>&1
                systemctl enable nginx >/dev/null 2>&1
                systemctl start nginx >/dev/null 2>&1
                CURRENT_WEBSERVER="nginx"
                print_success "Nginx installed and started"
                ;;
            3) exit 1 ;;
            *) print_error "Invalid choice"; exit 1 ;;
        esac
    fi
}

# Domain tracking functions
get_domain_count() {
    if [[ -f "$DOMAIN_LIST_FILE" ]]; then
        grep -c "^[^#]" "$DOMAIN_LIST_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

add_domain_to_list() {
    local domain="$1"
    local webserver="$2"
    local ssl_status="$3"
    local document_root="$4"
    
    mkdir -p "$(dirname "$DOMAIN_LIST_FILE")"
    
    if [[ -f "$DOMAIN_LIST_FILE" ]]; then
        grep -v "^$domain:" "$DOMAIN_LIST_FILE" > "$DOMAIN_LIST_FILE.tmp" 2>/dev/null || true
        mv "$DOMAIN_LIST_FILE.tmp" "$DOMAIN_LIST_FILE"
    fi
    
    echo "$domain:$webserver:$ssl_status:$document_root:$(date '+%Y-%m-%d %H:%M:%S')" >> "$DOMAIN_LIST_FILE"
    log_message "INFO" "Domain $domain added to tracking"
}

remove_domain_from_list() {
    local domain="$1"
    
    if [[ -f "$DOMAIN_LIST_FILE" ]]; then
        grep -v "^$domain:" "$DOMAIN_LIST_FILE" > "$DOMAIN_LIST_FILE.tmp" 2>/dev/null || true
        mv "$DOMAIN_LIST_FILE.tmp" "$DOMAIN_LIST_FILE"
        log_message "INFO" "Domain $domain removed from tracking"
    fi
}

# Auto-detect existing domains
auto_detect_domains() {
    print_section "Auto-Detecting Existing Domains"
    
    local detected_count=0
    mkdir -p "$(dirname "$DOMAIN_LIST_FILE")"
    touch "$DOMAIN_LIST_FILE"
    
    if [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        print_status "Scanning Nginx configurations..."
        
        for site_file in /etc/nginx/sites-available/*; do
            [[ ! -f "$site_file" ]] && continue
            [[ "$(basename "$site_file")" == "default" ]] && continue
            
            local domain=$(grep -E "^\s*server_name" "$site_file" | head -1 | awk '{print $2}' | sed 's/;//' | sed 's/www\.//')
            
            [[ -z "$domain" ]] && continue
            [[ "$domain" == "_" ]] && continue
            
            if ! grep -q "^$domain:" "$DOMAIN_LIST_FILE" 2>/dev/null; then
                local ssl_status="false"
                if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
                    ssl_status="true"
                fi
                
                local doc_root="/var/www/$domain"
                local config_root=$(grep -E "^\s*root" "$site_file" | head -1 | awk '{print $2}' | sed 's/;//')
                [[ -n "$config_root" ]] && doc_root="$config_root"
                
                echo "$domain:nginx:$ssl_status:$doc_root:$(date '+%Y-%m-%d %H:%M:%S')" >> "$DOMAIN_LIST_FILE"
                print_success "Imported: $domain"
                ((detected_count++))
            fi
        done
        
    elif [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        print_status "Scanning Apache configurations..."
        
        for site_file in /etc/apache2/sites-available/*.conf; do
            [[ ! -f "$site_file" ]] && continue
            [[ "$(basename "$site_file")" == "000-default.conf" ]] && continue
            [[ "$(basename "$site_file")" == "default-ssl.conf" ]] && continue
            
            local domain=$(grep -E "^\s*ServerName" "$site_file" | head -1 | awk '{print $2}')
            
            [[ -z "$domain" ]] && continue
            
            if ! grep -q "^$domain:" "$DOMAIN_LIST_FILE" 2>/dev/null; then
                local ssl_status="false"
                if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
                    ssl_status="true"
                fi
                
                local doc_root="/var/www/$domain"
                local config_root=$(grep -E "^\s*DocumentRoot" "$site_file" | head -1 | awk '{print $2}')
                [[ -n "$config_root" ]] && doc_root="$config_root"
                
                echo "$domain:apache:$ssl_status:$doc_root:$(date '+%Y-%m-%d %H:%M:%S')" >> "$DOMAIN_LIST_FILE"
                print_success "Imported: $domain"
                ((detected_count++))
            fi
        done
    fi
    
    if [[ $detected_count -gt 0 ]]; then
        print_success "Auto-detected $detected_count existing domains"
        log_message "INFO" "Auto-detected $detected_count domains"
    else
        print_info "No new domains found"
    fi
}

# Virtual host creation
create_apache_vhost() {
    local domain="$1"
    local document_root="$DOMAINS_ROOT/$domain"
    
    print_section "Creating Apache Virtual Host"
    
    mkdir -p "$document_root"
    
    cat > "/etc/apache2/sites-available/$domain.conf" << EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $document_root
    
    <Directory $document_root>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/$domain-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain-access.log combined
</VirtualHost>
EOF
    
    a2ensite "$domain.conf" >/dev/null 2>&1
    systemctl reload apache2 >/dev/null 2>&1
    
    create_default_website "$domain" "$document_root"
    
    print_success "Apache virtual host created"
    log_message "INFO" "Apache vhost created for $domain"
}

create_nginx_vhost() {
    local domain="$1"
    local document_root="$DOMAINS_ROOT/$domain"
    
    print_section "Creating Nginx Server Block"
    
    mkdir -p "$document_root"
    
    cat > "/etc/nginx/sites-available/$domain" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $document_root;
    index index.html index.php;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\. {
        deny all;
    }
}
EOF
    
    ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1
    
    create_default_website "$domain" "$document_root"
    
    print_success "Nginx server block created"
    log_message "INFO" "Nginx server block created for $domain"
}

create_default_website() {
    local domain="$1"
    local document_root="$2"
    
    cat > "$document_root/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; text-align: center; }
        h1 { color: #333; }
        p { color: #666; }
        .info { background: #f0f8ff; padding: 20px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>🚀 Welcome to $domain</h1>
    <p>Your domain is now configured and ready!</p>
    <div class="info">
        <p><strong>Document Root:</strong> $document_root</p>
        <p><strong>Web Server:</strong> $CURRENT_WEBSERVER</p>
        <p><strong>Server IP:</strong> $SERVER_IP</p>
    </div>
    <p>Replace this file with your website content.</p>
</body>
</html>
EOF
    
    chown -R www-data:www-data "$document_root"
    chmod -R 755 "$document_root"
}

# Domain management
add_domain() {
    print_header "Add New Domain"
    
    local domain
    echo -e "${WHITE}Enter domain name (e.g., example.com):${NC}"
    read -p "Domain: " domain
    
    [[ -z "$domain" ]] && { print_error "Domain cannot be empty"; return 1; }
    
    validate_domain "$domain" || return 1
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]] && [[ -f "/etc/apache2/sites-available/$domain.conf" ]]; then
        print_error "Domain $domain already exists for Apache"
        return 1
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]] && [[ -f "/etc/nginx/sites-available/$domain" ]]; then
        print_error "Domain $domain already exists for Nginx"
        return 1
    fi
    
    echo
    if confirm_action "Check DNS resolution for $domain?"; then
        check_domain_dns "$domain"
    fi
    
    echo
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        create_apache_vhost "$domain"
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        create_nginx_vhost "$domain"
    fi
    
    add_domain_to_list "$domain" "$CURRENT_WEBSERVER" "false" "$DOMAINS_ROOT/$domain"
    
    print_success "Domain $domain added successfully"
    print_info "Document root: $DOMAINS_ROOT/$domain"
    
    echo
    if confirm_action "Install SSL certificate for $domain?"; then
        install_ssl_certificate "$domain"
    fi
}

remove_domain() {
    print_header "Remove Domain"
    
    if ! list_domains_simple; then
        print_warning "No domains configured"
        return 0
    fi
    
    echo
    local domain
    read -p "Enter domain to remove: " domain
    
    [[ -z "$domain" ]] && { print_error "Domain cannot be empty"; return 1; }
    
    validate_domain "$domain" || return 1
    
    echo
    if ! confirm_action "Remove $domain and all its configuration?"; then
        print_info "Operation cancelled"
        return 0
    fi
    
    if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
        if [[ -f "/etc/apache2/sites-available/$domain.conf" ]]; then
            a2dissite "$domain.conf" >/dev/null 2>&1
            rm -f "/etc/apache2/sites-available/$domain.conf"
            systemctl reload apache2 >/dev/null 2>&1
        fi
    elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
        if [[ -f "/etc/nginx/sites-available/$domain" ]]; then
            rm -f "/etc/nginx/sites-enabled/$domain"
            rm -f "/etc/nginx/sites-available/$domain"
            systemctl reload nginx >/dev/null 2>&1
        fi
    fi
    
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        certbot delete --cert-name "$domain" --non-interactive >/dev/null 2>&1
    fi
    
    echo
    if confirm_action "Remove website files in $DOMAINS_ROOT/$domain?"; then
        rm -rf "$DOMAINS_ROOT/$domain"
        print_success "Website files removed"
    fi
    
    remove_domain_from_list "$domain"
    
    print_success "Domain $domain removed"
    log_message "INFO" "Domain $domain removed"
}

list_domains_simple() {
    if [[ ! -f "$DOMAIN_LIST_FILE" ]] || [[ ! -s "$DOMAIN_LIST_FILE" ]]; then
        return 1
    fi
    
    print_info "Configured domains:"
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        [[ -z "$domain" ]] && continue
        local ssl_indicator=""
        if [[ "$ssl_status" == "true" ]]; then
            ssl_indicator=" ${GREEN}[SSL]${NC}"
        fi
        echo "  ${BULLET} $domain$ssl_indicator"
    done < "$DOMAIN_LIST_FILE"
    
    return 0
}

list_domains_detailed() {
    print_header "Domain Overview"
    
    if [[ ! -f "$DOMAIN_LIST_FILE" ]] || [[ ! -s "$DOMAIN_LIST_FILE" ]]; then
        print_warning "No domains configured"
        return 0
    fi
    
    local domain_count=$(get_domain_count)
    print_info "Total domains: $domain_count"
    
    echo
    printf "%-25s %-10s %-8s %-10s %-20s\n" "Domain" "Server" "SSL" "Status" "Added"
    printf "%-25s %-10s %-8s %-10s %-20s\n" "------" "------" "---" "------" "-----"
    
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        [[ -z "$domain" ]] && continue
        
        local status="Unknown"
        local status_color="$GRAY"
        
        if timeout 3 curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null | grep -q "200"; then
            status="Active"
            status_color="$GREEN"
        fi
        
        local ssl_display="No"
        local ssl_color="$GRAY"
        if [[ "$ssl_status" == "true" ]]; then
            ssl_display="Yes"
            ssl_color="$GREEN"
        fi
        
        printf "%-25s %-10s ${ssl_color}%-8s${NC} ${status_color}%-10s${NC} %-20s\n" \
               "$domain" "$webserver" "$ssl_display" "$status" "$date_added"
    done < "$DOMAIN_LIST_FILE"
}

# SSL Management - Fixed Version
install_certbot() {
    if command -v certbot &> /dev/null; then
        return 0
    fi
    
    print_status "Installing Certbot..."
    apt update >/dev/null 2>&1
    apt install -y certbot >/dev/null 2>&1
    print_success "Certbot installed"
}

install_ssl_certificate() {
    local domain="$1"
    
    print_header "SSL Certificate Installation"
    
    install_certbot
    
    # Pre-flight check
    if ! timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://$domain" | grep -q "200"; then
        print_warning "Domain $domain is not accessible"
        if ! confirm_action "Continue anyway?"; then
            return 0
        fi
    fi
    
    local email
    read -p "Enter email for Let's Encrypt: " email
    
    [[ -z "$email" ]] && { print_error "Email required"; return 1; }
    
    print_section "Getting SSL Certificate"
    print_info "Using standalone method for better reliability"
    
    # Stop web server temporarily for standalone method
    print_status "Stopping $CURRENT_WEBSERVER temporarily..."
    systemctl stop "$CURRENT_WEBSERVER" >/dev/null 2>&1
    
    # Use standalone method - more reliable than nginx plugin
    print_status "Requesting SSL certificate..."
    local success=false
    
    if certbot certonly --standalone \
        -d "$domain" -d "www.$domain" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --verbose >/dev/null 2>&1; then
        success=true
    fi
    
    # Restart web server
    print_status "Restarting $CURRENT_WEBSERVER..."
    systemctl start "$CURRENT_WEBSERVER" >/dev/null 2>&1
    
    if [[ "$success" == true ]]; then
        print_success "SSL certificate obtained successfully"
        
        # Configure web server for SSL
        configure_ssl_nginx "$domain"
        
        # Update domain tracking
        if [[ -f "$DOMAIN_LIST_FILE" ]]; then
            sed -i "s/^$domain:$CURRENT_WEBSERVER:false:/$domain:$CURRENT_WEBSERVER:true:/" "$DOMAIN_LIST_FILE"
        fi
        
        print_success "SSL certificate installed and configured for $domain"
        print_info "Your site is now available at: https://$domain"
        log_message "INFO" "SSL installed for $domain"
    else
        print_error "SSL certificate installation failed"
        print_info "Common issues:"
        print_info "• Domain doesn't point to this server"
        print_info "• Port 80/443 blocked by firewall"
        print_info "• Rate limit reached (try again later)"
        
        # Check certbot logs for more details
        print_status "Checking error logs..."
        if [[ -f "/var/log/letsencrypt/letsencrypt.log" ]]; then
            local last_error=$(tail -10 /var/log/letsencrypt/letsencrypt.log | grep -i error | tail -1)
            [[ -n "$last_error" ]] && print_info "Last error: $last_error"
        fi
    fi
}

# Configure Nginx for SSL
configure_ssl_nginx() {
    local domain="$1"
    
    if [[ "$CURRENT_WEBSERVER" != "nginx" ]]; then
        return 0
    fi
    
    print_status "Configuring Nginx for SSL..."
    
    # Backup original config
    cp "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-available/$domain.backup"
    
    # Create SSL-enabled configuration
    cat > "/etc/nginx/sites-available/$domain" << EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    server_name $domain www.$domain;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - Main configuration
server {
    listen 443 ssl http2;
    server_name $domain www.$domain;
    root /var/www/$domain;
    index index.html index.php;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Let's Encrypt renewal
    location /.well-known/acme-challenge/ {
        root /var/www/$domain;
        allow all;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\. {
        deny all;
    }
}
EOF
    
    # Test and reload nginx
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx >/dev/null 2>&1
        print_success "Nginx SSL configuration applied"
    else
        print_error "Nginx configuration error, restoring backup"
        mv "/etc/nginx/sites-available/$domain.backup" "/etc/nginx/sites-available/$domain"
        systemctl reload nginx >/dev/null 2>&1
    fi
}

check_ssl_status() {
    print_header "SSL Certificate Status"
    
    if [[ ! -f "$DOMAIN_LIST_FILE" ]] || [[ ! -s "$DOMAIN_LIST_FILE" ]]; then
        print_warning "No domains configured"
        return 0
    fi
    
    printf "%-25s %-10s %-20s %s\n" "Domain" "SSL" "Expires" "Status"
    printf "%-25s %-10s %-20s %s\n" "------" "---" "-------" "------"
    
    while IFS=':' read -r domain webserver ssl_status document_root date_added; do
        [[ -z "$domain" ]] && continue
        
        if [[ "$ssl_status" == "true" ]]; then
            local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
            if [[ -f "$cert_path" ]]; then
                local expire_date=$(openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2)
                local expire_epoch=$(date -d "$expire_date" +%s 2>/dev/null || echo "0")
                local current_epoch=$(date +%s)
                local days_left=$(( (expire_epoch - current_epoch) / 86400 ))
                
                local status="Valid"
                if [[ $days_left -lt 30 ]]; then
                    status="Expires Soon"
                elif [[ $days_left -lt 0 ]]; then
                    status="Expired"
                fi
                
                printf "%-25s %-10s %-20s %s\n" "$domain" "Yes" "$expire_date" "$status ($days_left days)"
            else
                printf "%-25s %-10s %-20s %s\n" "$domain" "Yes" "Unknown" "Cert not found"
            fi
        else
            printf "%-25s %-10s %-20s %s\n" "$domain" "No" "N/A" "No SSL"
        fi
    done < "$DOMAIN_LIST_FILE"
}

# Menus
display_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                         🌐 VPS DOMAIN MANAGER                             ║
  ║                           Production Ready v2.1                             ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_main_menu() {
    while true; do
        clear
        display_banner
        
        echo -e "${BLUE}${BOLD}Current Configuration:${NC}"
        echo -e "Web Server: ${GREEN}$CURRENT_WEBSERVER${NC}  Server IP: ${GREEN}$SERVER_IP${NC}"
        
        local domain_count=$(get_domain_count)
        echo -e "Configured Domains: ${GREEN}$domain_count${NC}"
        
        print_section "Main Menu"
        echo -e "${WHITE}1.${NC} ➕ Add New Domain"
        echo -e "${WHITE}2.${NC} ➖ Remove Domain"
        echo -e "${WHITE}3.${NC} 📋 List Domains"
        echo -e "${WHITE}4.${NC} 🔒 SSL Management"
        echo -e "${WHITE}5.${NC} ❌ Exit"
        echo
        
        local choice
        read -p "Choose option [1-5]: " choice
        
        case $choice in
            1) add_domain; echo; read -p "Press Enter to continue..." ;;
            2) remove_domain; echo; read -p "Press Enter to continue..." ;;
            3) list_domains_detailed; echo; read -p "Press Enter to continue..." ;;
            4) ssl_menu ;;
            5) print_success "Goodbye!"; exit 0 ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

ssl_menu() {
    while true; do
        print_header "SSL Management"
        
        echo -e "${WHITE}1.${NC} 🔒 Install SSL Certificate"
        echo -e "${WHITE}2.${NC} 📊 Check SSL Status"
        echo -e "${WHITE}3.${NC} 🔙 Back to Main Menu"
        echo
        
        local choice
        read -p "Choose option [1-3]: " choice
        
        case $choice in
            1) 
                if list_domains_simple; then
                    echo
                    local domain
                    read -p "Enter domain name: " domain
                    if [[ -n "$domain" ]] && validate_domain "$domain"; then
                        install_ssl_certificate "$domain"
                    fi
                else
                    print_warning "No domains configured"
                fi
                echo; read -p "Press Enter to continue..."
                ;;
            2) check_ssl_status; echo; read -p "Press Enter to continue..." ;;
            3) break ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

# Main execution
main() {
    print_header "VPS Domain Management v$SCRIPT_VERSION"
    
    check_root
    
    mkdir -p "$SCRIPT_DIR"/{logs,config}
    
    print_status "Getting server IP address..."
    get_server_ip >/dev/null
    print_success "Server IP: $SERVER_IP"
    
    log_message "INFO" "Domain Manager started v$SCRIPT_VERSION"
    
    detect_webserver
    ensure_webserver
    
    auto_detect_domains
    
    show_main_menu
}

# Main execution - handle arguments
if [[ ${#} -eq 0 ]]; then
    # No arguments - run interactive mode
    main
else
    # Handle command line arguments
    case "$1" in
        --add)
            check_root
            get_server_ip >/dev/null
            detect_webserver
            ensure_webserver
            auto_detect_domains
            
            if [[ -n "${2:-}" ]] && validate_domain "${2:-}"; then
                domain="$2"
                if [[ "$CURRENT_WEBSERVER" == "apache" ]]; then
                    create_apache_vhost "$domain"
                elif [[ "$CURRENT_WEBSERVER" == "nginx" ]]; then
                    create_nginx_vhost "$domain"
                fi
                add_domain_to_list "$domain" "$CURRENT_WEBSERVER" "false" "$DOMAINS_ROOT/$domain"
                print_success "Domain $domain added"
            else
                print_error "Usage: $0 --add <domain>"
                exit 1
            fi
            ;;
        --list)
            check_root
            get_server_ip >/dev/null
            detect_webserver
            auto_detect_domains
            if [[ -f "$DOMAIN_LIST_FILE" ]]; then
                list_domains_detailed
            else
                print_warning "No domains configured"
            fi
            ;;
        --ssl)
            check_root
            get_server_ip >/dev/null
            detect_webserver
            
            if [[ -n "${2:-}" ]] && validate_domain "${2:-}"; then
                install_ssl_certificate "$2"
            else
                print_error "Usage: $0 --ssl <domain>"
                exit 1
            fi
            ;;
        --help)
            echo "VPS Domain Manager v$SCRIPT_VERSION"
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --add <domain>    Add domain"
            echo "  --list            List domains"
            echo "  --ssl <domain>    Install SSL"
            echo "  --help            Show help"
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi
