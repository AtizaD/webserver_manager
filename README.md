# 🚀 Professional Web Server Manager

A comprehensive, intelligent web server management system for Ubuntu 22.04 with seamless Apache/Nginx switching, smart package detection, and advanced domain management.

## ✨ Features

### 🔄 **Smart Server Switching**
- **Seamless Apache ↔ Nginx switching** with automatic site migration
- **Zero-downtime** configuration testing and rollback
- **Intelligent config conversion** preserving all settings
- **Automatic backup** before any changes

### 🧠 **Intelligent Package Management**
- **Smart detection** - skips already installed packages
- **Version compatibility** checking and upgrades
- **Selective installation** - only installs what's missing
- **Fast re-runs** - no redundant installations

### 🛡️ **Production-Ready Security**
- **Optimized configurations** for both Apache and Nginx
- **Security headers** and performance tuning
- **Firewall management** with UFW
- **SSL certificate** automation with Let's Encrypt

### 🌐 **Advanced Domain Management**
- **Interactive domain** addition and removal
- **SSL certificate** management (add/remove/renew)
- **Site status** monitoring and diagnostics
- **Real-time system** information dashboard

## 📦 **Complete Stack Support**

### **LEMP Stack** (Linux + Nginx + MariaDB + PHP)
- **Nginx** with optimized performance settings
- **PHP 8.2** with 20+ extensions
- **MariaDB** (superior to MySQL)
- **Composer** for PHP package management
- **Node.js + npm** for modern development

### **LAMP Stack** (Linux + Apache + MariaDB + PHP)
- **Apache** with mod_rewrite and security modules
- **PHP 8.2** with full extension suite
- **MariaDB** database server
- **Complete development** environment

## 🚀 **Quick Start**

### **Installation**

```bash
# Download the scripts
wget https://raw.githubusercontent.com/AtizaD/webserver_manager/main/server-manager
wget https://raw.githubusercontent.com/AtizaD/webserver_manager/main/domain-manager

# Make executable
chmod +x server-manager domain-manager

# Move to system path
sudo mv server-manager domain-manager /usr/local/bin/

# Launch interactive interface
sudo server-manager
```

### **Quick Commands**

```bash
# Server Management
sudo server-manager install-lemp    # Install LEMP stack
sudo server-manager install-lamp    # Install LAMP stack
sudo server-manager switch-nginx    # Switch to Nginx
sudo server-manager switch-apache   # Switch to Apache
sudo server-manager status          # Show system status

# Domain Management
sudo domain-manager add example.com      # Add domain
sudo domain-manager ssl-add example.com  # Add SSL certificate
sudo domain-manager list                 # List all domains
sudo domain-manager status example.com   # Check domain status
```

## 🎛️ **Interactive Interfaces**

### **Server Manager Menu**
```
╔══════════════════════════════════════════════════════════════╗
║                    Server Manager v1.0                      ║
║                 Web Server Management                       ║
╚══════════════════════════════════════════════════════════════╝

Current Server: Nginx Running

🚀 Installation Options:
1. Install LEMP Stack (Linux + Nginx + MySQL + PHP)
2. Install LAMP Stack (Linux + Apache + MySQL + PHP)
3. Install Individual Components

🔄 Server Management:
4. Switch to Apache (with site migration)
5. Restart Nginx

📊 Information:
6. Show System Status
7. Show Configuration Backups

🌐 Domain Management:
8. Domain Manager (Add/Remove Domains & SSL)

0. Exit
```

### **Domain Manager Menu**
```
╔══════════════════════════════════════════════════════════════╗
║                    Domain Manager v1.0                      ║
║                  Interactive Management                     ║
╚══════════════════════════════════════════════════════════════╝

📊 System Status:
   Server:              nginx (Running)
   Available Domains:   3
   SSL Certificates:    2
   Public IP:           142.93.245.178
   Uptime:              up 2 days, 5 hours

🚀 Management Options:
1. Add Domain
2. Remove Domain
3. List All Domains
4. Check Domain Status
5. Enable Domain
6. Disable Domain
7. Add SSL Certificate
8. Remove SSL Certificate
9. Renew SSL Certificates
10. Server Information
11. Server Manager (Switch Apache/Nginx)

0. Exit
```

## 🧠 **Smart Features**

### **Context-Aware Menus**
- **Dynamic options** based on current server state
- **Intelligent suggestions** for optimal workflows
- **Conflict detection** with guided resolution
- **Safe operations** with automatic validation

### **Advanced Package Detection**
- **Real-time status** checking for all components
- **Version compatibility** validation
- **Dependency resolution** and conflict handling
- **Graceful failure** recovery with detailed logging

### **Site Migration Intelligence**
- **Automatic config** translation between Apache/Nginx
- **Document root** preservation and validation
- **SSL certificate** handling during switches
- **Performance optimization** maintenance

## 🛡️ **Security & Performance**

### **Optimized Configurations**
- **Nginx**: Gzip compression, security headers, rate limiting
- **Apache**: ModSecurity, compression, caching headers
- **PHP**: OPcache, security settings, performance tuning
- **MariaDB**: Secure installation and optimization

### **SSL Management**
- **Automatic certificate** generation with Let's Encrypt
- **Multi-domain support** with wildcard options
- **Auto-renewal** with cron integration
- **Perfect Forward Secrecy** and modern cipher suites

## 📊 **System Requirements**

- **OS**: Ubuntu 22.04 LTS (recommended)
- **Memory**: 1GB RAM minimum, 2GB+ recommended
- **Storage**: 10GB free space minimum
- **Network**: Internet connection for package downloads
- **Privileges**: Root/sudo access required

## 🎯 **Use Cases**

### **Perfect For:**
- **Web developers** managing multiple projects
- **System administrators** handling web servers
- **DevOps engineers** automating deployments
- **Small businesses** running websites
- **Agencies** managing client sites

### **Ideal Scenarios:**
- **Server migration** from Apache to Nginx (or vice versa)
- **New server** setup with complete LEMP/LAMP stack
- **Domain management** with SSL automation
- **Performance optimization** and security hardening
- **Development environment** setup

## 🔄 **Migration Workflows**

### **Apache to Nginx Migration**
1. **Backup** current Apache configuration
2. **Install** Nginx with optimized settings
3. **Convert** Apache virtual hosts to Nginx server blocks
4. **Test** configuration validity
5. **Switch** services with zero downtime
6. **Verify** all sites are working correctly

### **LAMP to LEMP Conversion**
1. **Detect** current LAMP components
2. **Preserve** all databases and websites
3. **Install** missing LEMP components
4. **Migrate** server configurations
5. **Update** firewall rules
6. **Complete** with performance testing

## 📈 **Performance Benefits**

### **Nginx Advantages**
- **High concurrency** handling (10,000+ connections)
- **Low memory** footprint
- **Better static** file serving
- **Advanced load** balancing capabilities

### **Apache Advantages**
- **Extensive module** ecosystem
- **Better PHP** integration options
- **Flexible configuration** with .htaccess
- **Mature documentation** and community

## 🔧 **Technical Details**

### **Components Installed**
- **Web Servers**: Nginx 1.22+ or Apache 2.4+
- **PHP**: 8.2 with extensions (mysql, gd, curl, zip, xml, mbstring, bcmath, intl, soap, opcache, xdebug)
- **Database**: MariaDB 10.6+ (MySQL compatible)
- **Package Managers**: Composer (PHP), npm (Node.js)
- **Runtime**: Node.js LTS with Yarn and PM2
- **Security**: UFW firewall, Fail2ban, SSL certificates

### **Directory Structure**
```
/etc/nginx/sites-available/    # Nginx virtual hosts
/etc/nginx/sites-enabled/      # Active Nginx sites
/etc/apache2/sites-available/  # Apache virtual hosts  
/etc/apache2/sites-enabled/    # Active Apache sites
/var/www/                      # Web document roots
/var/backups/server-manager/   # Configuration backups
/var/log/server-manager.log    # Management logs
```

## 🤝 **Contributing**

We welcome contributions! Please feel free to:
- **Report bugs** and suggest features
- **Submit pull requests** with improvements
- **Share your** deployment experiences
- **Help improve** documentation

## 📝 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 **Support**

- **Documentation**: Check the inline help with `--help` commands
- **Logs**: Review `/var/log/server-manager.log` for detailed information
- **Issues**: Report problems via GitHub Issues
- **Community**: Share experiences and get help from other users

## 🚀 **Roadmap**

- **Multi-OS support** (CentOS, Debian)
- **Docker integration** for containerized deployments  
- **Database cluster** management
- **Advanced monitoring** and alerting
- **API interface** for programmatic control

---

**Built with ❤️ for system administrators and web developers who value reliability, security, and ease of use.**