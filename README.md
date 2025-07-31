# Web Server Manager

A comprehensive web server management suite for Ubuntu 22.04, providing automated installation, configuration, and management of web servers with MySQL database integration.

## Components

### 1. Server Manager (`server-manager`)
Intelligent web server switching and stack management tool.

**Features:**
- **LEMP Stack** (Linux + Nginx + MySQL + PHP)
- **LAMP Stack** (Linux + Apache + MySQL + PHP)
- Automated site migration between Nginx and Apache
- PHP 8.2 with extensions
- MySQL database server
- Composer and Node.js integration
- Interactive management interface

### 2. Domain Manager (`domain-manager`)
Domain and SSL certificate management tool.

**Features:**
- Add/remove domains with automated configuration
- SSL certificate management with Let's Encrypt
- Nginx virtual host generation
- Domain status monitoring
- Interactive management interface

## Installation

1. Copy scripts to system PATH:
```bash
sudo cp server-manager /usr/local/bin/
sudo cp domain-manager /usr/local/bin/
sudo chmod +x /usr/local/bin/server-manager
sudo chmod +x /usr/local/bin/domain-manager
```

## Usage

### Server Manager
```bash
# Interactive mode
server-manager

# Command line usage
server-manager install-lemp      # Install LEMP stack
server-manager install-lamp      # Install LAMP stack
server-manager switch-nginx      # Switch to Nginx
server-manager switch-apache     # Switch to Apache
server-manager status            # Show system status
server-manager secure-mysql      # Secure MySQL installation
```

### Domain Manager
```bash
# Interactive mode
domain-manager

# Command line usage
domain-manager add example.com           # Add domain
domain-manager ssl-add example.com       # Add SSL certificate
domain-manager remove example.com        # Remove domain
domain-manager list                      # List all domains
domain-manager status example.com        # Check domain status
```

## Database Configuration

This tool uses **MySQL** as the database server instead of MariaDB:
- Installs `mysql-server` and `mysql-client` packages
- Uses `mysql` systemd service
- Compatible with standard MySQL configuration and tools

## Requirements

- Ubuntu 22.04 LTS
- Root access
- Internet connection for package installation

## Stack Components

### LEMP Stack
- **Linux**: Ubuntu 22.04
- **Nginx**: Latest stable version
- **MySQL**: Latest stable version
- **PHP**: 8.2 with extensions

### LAMP Stack
- **Linux**: Ubuntu 22.04
- **Apache**: Latest stable version
- **MySQL**: Latest stable version
- **PHP**: 8.2 with extensions

### Additional Tools
- **Composer**: PHP dependency manager
- **Node.js**: Latest LTS with npm and yarn
- **PM2**: Process manager for Node.js
- **Certbot**: SSL certificate management

## Security Features

- Automated firewall configuration
- SSL/TLS certificate management
- Security headers configuration
- Fail2ban integration
- MySQL security hardening

## Backup and Migration

- Automatic configuration backups before major changes
- Site migration between web servers
- SSL certificate preservation during switches

## Support

For issues and documentation:
- Check log files: `/var/log/server-manager.log` and `/var/log/domain-manager.log`
- Backup location: `/var/backups/server-manager/`

## License

This project is open source and available under standard licensing terms.