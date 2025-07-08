# 🚀 VPS Management Suite

> **Professional-grade VPS management tools for Ubuntu/Debian servers**

A comprehensive, production-ready suite of bash scripts for managing web servers, domains, SSL certificates, and system configurations on Ubuntu/Debian VPS instances. Built with enterprise-level features, beautiful UI, and robust error handling.

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/yourusername/vps-manager)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/ubuntu-18.04%2B-orange.svg)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/debian-10%2B-red.svg)](https://debian.org/)

## ✨ Features

### 🎯 **Core Capabilities**
- **Intelligent Web Server Management** - Apache & Nginx with seamless switching
- **Advanced Domain Management** - Virtual hosts, SSL certificates, DNS checking
- **Database Management** - MySQL, MariaDB, PostgreSQL with optimized configurations
- **Automated SSL/TLS** - Let's Encrypt integration with auto-renewal
- **System Backup & Restore** - Google Drive integration with compression
- **Security Hardening** - UFW firewall, Fail2Ban, security headers

### 🎨 **User Experience**
- **Beautiful Terminal UI** - Color-coded output, progress bars, spinners
- **Interactive Menus** - Intuitive navigation with confirmation dialogs
- **Real-time Progress** - Visual feedback for long-running operations
- **Smart Validation** - Input validation with helpful error messages
- **Comprehensive Logging** - Detailed audit trails and troubleshooting

### 🛡️ **Production Ready**
- **Error Handling** - Graceful failure recovery with rollback capabilities
- **Signal Handling** - Clean shutdown on interruption (Ctrl+C)
- **Version Management** - Automatic script updates with backup/restore
- **Network Resilience** - Timeout handling and retry mechanisms
- **Security First** - Secure defaults, input sanitization, permission management

## 📦 Installation

### Quick Start
```bash
# Download and run the main launcher
wget https://raw.githubusercontent.com/yourusername/vps-manager/main/main.sh
chmod +x main.sh
sudo ./main.sh
```

### Manual Installation
```bash
# Download all scripts
wget https://raw.githubusercontent.com/yourusername/vps-manager/main/main.sh
wget https://raw.githubusercontent.com/yourusername/vps-manager/main/server.sh
wget https://raw.githubusercontent.com/yourusername/vps-manager/main/domain.sh

# Make executable
chmod +x *.sh

# Run main launcher
sudo ./main.sh
```

### Git Clone
```bash
git clone https://github.com/yourusername/vps-manager.git
cd vps-manager
chmod +x *.sh
sudo ./main.sh
```

## 🏗️ Architecture

The suite consists of three main components:

### `main.sh` - Central Management Hub
- **Auto-downloading** - Downloads and updates other scripts automatically
- **Quick Setup Wizards** - LAMP/LEMP stack automation
- **System Monitoring** - Resource usage, service status, health checks
- **Update Management** - Version checking and intelligent updates

### `server.sh` - Server Configuration Manager
- **Web Servers** - Apache/Nginx installation and switching
- **PHP Management** - Latest versions with optimized configurations
- **Database Systems** - MySQL, MariaDB, PostgreSQL with security
- **Backup Systems** - Google Drive integration and system snapshots

### `domain.sh` - Domain & SSL Manager
- **Virtual Hosts** - Automatic configuration generation
- **SSL Certificates** - Let's Encrypt automation with monitoring
- **DNS Validation** - Health checks and troubleshooting
- **Domain Monitoring** - Status tracking and renewal alerts

## 🚀 Usage Examples

### Interactive Mode (Recommended)
```bash
# Launch main interface
sudo ./main.sh

# Direct access to specific managers
sudo ./main.sh --server    # Server management
sudo ./main.sh --domain    # Domain management
```

### Quick Setup Wizards
```bash
# Automated LAMP stack (Apache + MySQL + PHP)
sudo ./main.sh --setup
# Choose option 1 for LAMP

# Automated LEMP stack (Nginx + MySQL + PHP)
sudo ./server.sh --lemp

# Direct installations
sudo ./server.sh --lamp    # LAMP stack
sudo ./server.sh --lemp    # LEMP stack
```

### Command Line Interface
```bash
# Domain management
sudo ./domain.sh --add example.com        # Add domain
sudo ./domain.sh --ssl example.com        # Install SSL
sudo ./domain.sh --list                   # List domains

# System operations
sudo ./main.sh --status                   # System status
sudo ./main.sh --update                   # Update scripts
sudo ./main.sh --check-updates            # Check for updates
```

## 📋 Requirements

### System Requirements
- **OS**: Ubuntu 18.04+ or Debian 10+
- **RAM**: 1GB minimum, 2GB recommended
- **Disk**: 10GB free space minimum
- **Network**: Internet connection for package downloads

### Access Requirements
- **Root privileges** (`sudo` access)
- **SSH access** (for remote management)
- **Port access**: 22 (SSH), 80 (HTTP), 443 (HTTPS)

### Optional Requirements
- **Domain name** (for SSL certificates)
- **Google Drive account** (for cloud backups)
- **Email address** (for Let's Encrypt notifications)

## 🎛️ Configuration

### Directory Structure
```
/opt/vps_manager/
├── logs/
│   ├── main.log
│   ├── server.log
│   └── domain.log
├── config/
│   ├── main.conf
│   └── domains.conf
└── backups/
    └── system_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Environment Variables
```bash
# Optional: Customize installation directory
export VPS_MANAGER_DIR="/opt/vps_manager"

# Optional: Set default backup location
export BACKUP_DIR="/opt/vps_manager/backups"

# Optional: Custom repository URL
export SCRIPT_BASE_URL="https://raw.githubusercontent.com/yourusername/vps-manager/main"
```

## 🔧 Advanced Usage

### Automated Deployments
```bash
# Unattended LAMP installation
sudo ./server.sh --lamp

# Batch domain addition
for domain in example1.com example2.com; do
    sudo ./domain.sh --add "$domain"
    sudo ./domain.sh --ssl "$domain"
done
```

### Backup and Restore
```bash
# Setup Google Drive backup
sudo ./server.sh
# Choose: Backup Management > Setup Google Drive backup

# Create system backup
sudo ./server.sh
# Choose: Backup Management > Create System Backup

# Automated backup with cron
0 2 * * 0 /path/to/server.sh --backup-create
```

### SSL Management
```bash
# Bulk SSL installation
sudo ./domain.sh --ssl-bulk

# Certificate monitoring
sudo ./domain.sh --ssl-status

# Auto-renewal setup
sudo ./domain.sh
# Choose: SSL Management > Setup Auto-Renewal
```

## 📊 Screenshots

### Main Interface
```
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║  ██╗   ██╗██████╗ ███████╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗  ║
  ║  ██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝  ║
  ║  ██║   ██║██████╔╝███████╗    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗ ║
  ║  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║ ║
  ║   ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝ ║
  ║    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝  ║
  ╚══════════════════════════════════════════════════════════════════════════════╝

                    Professional VPS Management Suite v2.0
                          Ubuntu/Debian Server Management

System: Ubuntu 22.04  IP: 203.0.113.1
Services: Apache: Running  Nginx: Stopped  Database: MySQL
```

### Progress Indicators
```
Progress: [████████████████████████████████████████████████████] 100% Installing PHP 8.2
⠋ Installing SSL certificate with Apache...
✓ Domain example.com added successfully
```

## 🔍 Troubleshooting

### Common Issues

#### "Permission denied" errors
```bash
# Ensure scripts are executable
chmod +x *.sh

# Run with sudo
sudo ./main.sh
```

#### Web server won't start
```bash
# Check for port conflicts
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Check logs
sudo journalctl -u apache2 -f
sudo journalctl -u nginx -f
```

#### SSL certificate installation fails
```bash
# Verify domain points to server
dig +short example.com

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Verify web server is accessible
curl -I http://example.com
```

#### Google Drive backup issues
```bash
# Reconfigure rclone
rclone config

# Test connection
rclone lsd gdrive:

# Check logs
tail -f /opt/vps_manager/logs/server.log
```

### Debug Mode
```bash
# Enable debug output
export DEBUG=1
sudo ./main.sh

# View detailed logs
tail -f /opt/vps_manager/logs/*.log
```

### Support Resources
- **Logs Location**: `/opt/vps_manager/logs/`
- **Configuration**: `/opt/vps_manager/config/`
- **Backup Files**: `/opt/vps_manager/backups/`
- **System Status**: `sudo ./main.sh --status`

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/yourusername/vps-manager.git
cd vps-manager

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
sudo ./main.sh --status

# Submit pull request
```

### Code Style
- Follow existing bash scripting conventions
- Include comprehensive error handling
- Add logging for all major operations
- Update documentation for new features
- Test on Ubuntu 20.04+ and Debian 10+

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Let's Encrypt** - Free SSL certificates
- **Ondrej Surý** - PHP PPA maintenance
- **Rclone** - Cloud storage integration
- **UFW/Fail2Ban** - Security tools
- **Community Contributors** - Bug reports and feature requests

## 📞 Support

### Community Support
- **GitHub Issues**: [Report bugs or request features](https://github.com/yourusername/vps-manager/issues)
- **Discussions**: [Community discussions and Q&A](https://github.com/yourusername/vps-manager/discussions)

### Commercial Support
For enterprise support, custom development, or consultation services, please contact us at [support@example.com](mailto:support@example.com).

## 🗺️ Roadmap

### v2.1 (Planned)
- [ ] Docker container management
- [ ] Automatic security updates
- [ ] Web-based dashboard
- [ ] Multi-server management
- [ ] Advanced monitoring and alerts

### v2.2 (Future)
- [ ] Kubernetes integration
- [ ] CI/CD pipeline support
- [ ] Custom app templates
- [ ] API access
- [ ] Mobile app companion

---

<div align="center">

**Made with ❤️ for the DevOps community**

[⭐ Star this project](https://github.com/yourusername/vps-manager) • [🐛 Report Bug](https://github.com/yourusername/vps-manager/issues) • [💡 Request Feature](https://github.com/yourusername/vps-manager/issues)

</di
