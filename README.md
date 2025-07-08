# 🚀 VPS Management Suite

> **Professional Ubuntu/Debian server management in 3 smart scripts**

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/AtizaD/webserver_manager)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/ubuntu-18.04%2B-orange.svg)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/debian-10%2B-red.svg)](https://debian.org/)

## ⚡ Quick Start

```bash
# One-line installation
bash <(curl -s https://raw.githubusercontent.com/AtizaD/webserver_manager/main/main.sh)
```

## 🎯 What It Does

**🖥️ Server Manager** - Apache/Nginx, PHP, MySQL/MariaDB/PostgreSQL, security, backups  
**🌐 Domain Manager** - Virtual hosts, SSL certificates, DNS validation  
**🎛️ Main Hub** - Beautiful UI, auto-updates, LAMP/LEMP wizards  

## ✨ Key Features

- **One-click LAMP/LEMP** setup with optimized configs
- **Auto SSL** certificates with Let's Encrypt + renewal
- **Smart switching** between Apache ↔ Nginx 
- **Google Drive** backups with compression
- **Security hardening** (UFW + Fail2Ban)
- **Beautiful terminal UI** with progress bars & spinners

## 🎨 Interface Preview

```
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                    🚀 VPS MANAGEMENT SUITE v2.0                           ║
  ╚══════════════════════════════════════════════════════════════════════════════╝

System: Ubuntu 22.04  IP: 203.0.113.1
Services: Apache: ✓ Running  MySQL: ✓ Running  SSL: ✓ 3 domains

Progress: [████████████████████████████████████████████████████] 100% Installing SSL
⠋ Configuring virtual host...
✓ Domain example.com added successfully
```

## 🛠️ Usage

### Interactive Mode (Recommended)
```bash
sudo ./main.sh                 # Main interface
sudo ./server.sh               # Server management  
sudo ./domain.sh               # Domain management
```

### Quick Commands
```bash
# Automated stacks
sudo ./server.sh --lamp        # Apache + MySQL + PHP
sudo ./server.sh --lemp        # Nginx + MySQL + PHP

# Domain operations  
sudo ./domain.sh --add example.com
sudo ./domain.sh --ssl example.com
sudo ./domain.sh --list

# System operations
sudo ./main.sh --status        # System overview
sudo ./main.sh --update        # Update scripts
```

## 📦 Manual Installation

```bash
# Download all scripts
wget https://raw.githubusercontent.com/AtizaD/webserver_manager/main/{main,server,domain}.sh
chmod +x *.sh
sudo ./main.sh

# Or clone repository
git clone https://github.com/AtizaD/webserver_manager.git
cd webserver_manager && chmod +x *.sh && sudo ./main.sh
```

## ⚙️ Requirements

- **OS**: Ubuntu 18.04+ or Debian 10+
- **RAM**: 1GB+ (2GB recommended)
- **Access**: Root/sudo privileges
- **Network**: Ports 22, 80, 443 open

## 🔧 Configuration

Scripts auto-create structure in `/opt/vps_manager/`:
```
/opt/vps_manager/
├── logs/           # Operation logs
├── config/         # Domain tracking
└── backups/        # System snapshots
```

## 🆘 Quick Fixes

**Permission denied**
```bash
chmod +x *.sh && sudo ./main.sh
```

**Web server won't start**
```bash
sudo netstat -tlnp | grep :80    # Check port conflicts
sudo journalctl -u apache2 -f    # Check logs
```

**SSL fails**
```bash
dig +short example.com            # Verify DNS
sudo ufw allow 80,443/tcp         # Open firewall
curl -I http://example.com        # Test accessibility
```

**Variable conflicts**
```bash
# If you see "readonly variable" errors:
killall bash && sudo ./main.sh
```

## 🎯 Smart Features

### Auto-Detection
- Detects existing web servers and configurations
- Smart version checking with auto-updates
- DNS validation before SSL installation

### Production Ready
- Comprehensive error handling with rollback
- Security-first defaults and hardening
- Optimized configurations for performance

### User Experience  
- Color-coded status indicators
- Real-time progress tracking
- Confirmation dialogs for destructive actions

## 🤝 Contributing

```bash
git clone https://github.com/AtizaD/webserver_manager.git
cd webserver_manager
# Make changes and submit PR
```

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/AtizaD/webserver_manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AtizaD/webserver_manager/discussions)
- **Logs**: `/opt/vps_manager/logs/` for troubleshooting

## 📄 License

MIT License - see [LICENSE](LICENSE) file

---

<div align="center">

**⭐ Star this repo if it helped you!**

[⭐ Star](https://github.com/AtizaD/webserver_manager) • [🐛 Report Bug](https://github.com/AtizaD/webserver_manager/issues) • [💡 Request Feature](https://github.com/AtizaD/webserver_manager/issues)

</div>
