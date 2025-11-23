<div align="center">

# 🏠 Synology DS 224+ Production Container Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Synology](https://img.shields.io/badge/Synology-DSM%207.x-orange)](https://www.synology.com/)
[![Security: A+](https://img.shields.io/badge/Security-A+-success)](docs/SECURITY.md)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-green.svg)](https://github.com/morandeirachema/synology_containers/graphs/commit-activity)

**A production-ready, security-hardened Docker container stack for Synology DS 224+ (16GB RAM) featuring 12 essential services optimized for privacy, productivity, and comprehensive monitoring.**

[Features](#-key-features) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Services](#-service-catalog) • [Security](#-security--privacy) • [Support](#-support--community)

---

</div>

## 📑 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Service Catalog](#-service-catalog)
- [System Architecture](#-system-architecture)
- [Quick Start](#-quick-start)
- [System Requirements](#-system-requirements)
- [Installation Guide](#-installation-guide)
- [Configuration](#-configuration)
- [Service Access Points](#-service-access-points)
- [Security & Privacy](#-security--privacy)
- [Performance Optimization](#-performance-optimization)
- [Backup & Recovery](#-backup--recovery)
- [Monitoring & Maintenance](#-monitoring--maintenance)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)
- [FAQ](#-frequently-asked-questions)
- [Community & Support](#-support--community)
- [Contributing](#-contributing)
- [Roadmap](#-roadmap)
- [Changelog](#-changelog)
- [License](#-license)
- [Acknowledgments](#-acknowledgments)

---

## 🎯 Overview

This repository provides a **complete, production-ready Docker environment** specifically optimized for Synology NAS devices. It implements industry best practices for security, performance, and maintainability, making it suitable for both home labs and small business deployments.

### What Makes This Special?

- **🔐 Security First**: A+ rated security with automatic HTTPS, 2FA on all services, and network isolation
- **⚡ Optimized for Synology**: Tuned specifically for DS 224+ with proper permissions and resource limits
- **📦 Zero-Touch SSL**: Automatic certificate management via Let's Encrypt and CloudFlare DNS
- **🎯 Production Ready**: Battle-tested configurations with health checks and auto-restart policies
- **📊 Full Observability**: Complete monitoring stack with metrics, logs, and uptime tracking
- **🔄 Easy Updates**: Safe update mechanisms with automated backups and rollback capabilities
- **📚 Comprehensive Docs**: 150+ pages of documentation, guides, and troubleshooting

### Use Cases

- **Home Server**: Centralized file storage, password management, and VPN access
- **Small Office**: Secure document sharing, monitoring, and remote access
- **Development Environment**: Container management and testing platform
- **Learning Platform**: Hands-on experience with Docker, networking, and system administration

---

## ✨ Key Features

### 🔒 Security & Privacy

- ✅ **Automatic HTTPS** with Let's Encrypt certificates (auto-renewal)
- ✅ **Two-Factor Authentication** (2FA) via Authelia on all external services
- ✅ **Secure VPN Access** with WireGuard for encrypted remote connections
- ✅ **Network Segmentation** with isolated Docker networks
- ✅ **Security Headers** (HSTS, CSP, X-Frame-Options, etc.)
- ✅ **Rate Limiting** to prevent brute-force attacks
- ✅ **No Root Containers** - all services run as non-privileged users
- ✅ **Secret Management** via environment variables (no hardcoded credentials)
- ✅ **Regular Security Scanning** compatible with Trivy and similar tools

### 🚀 Performance & Reliability

- ✅ **Resource Limits** preventing OOM (Out of Memory) kills
- ✅ **Health Checks** for all critical services
- ✅ **Auto-Restart Policies** for high availability
- ✅ **SSD Cache Optimization** for Synology storage
- ✅ **Log Rotation** preventing disk space exhaustion
- ✅ **Database Query Optimization** for PostgreSQL and MariaDB
- ✅ **Efficient RAM Usage** (~6.5GB/16GB, leaving 60% free)

### 📊 Monitoring & Observability

- ✅ **Prometheus Metrics Collection** from all services
- ✅ **Grafana Dashboards** for visualization
- ✅ **Container Metrics** via cAdvisor
- ✅ **Uptime Monitoring** with Uptime Kuma
- ✅ **Real-Time Logs** via Dozzle
- ✅ **Update Notifications** via Diun

### 🛠️ Management & Maintenance

- ✅ **Web-Based Management** with Portainer
- ✅ **Automated Backups** with retention policies
- ✅ **One-Command Updates** for all services
- ✅ **Health Check Scripts** for diagnostics
- ✅ **Beautiful Dashboard** (Homepage) as central hub
- ✅ **Version Pinning** for stability (no `:latest` tags)

---

## 📦 Service Catalog

### 🔒 Security & Privacy Layer (5 Services)

<details>
<summary><b>Click to expand Security Services details</b></summary>

#### 1. Traefik - Edge Router & Reverse Proxy
- **Purpose**: Automatic HTTPS, request routing, load balancing
- **Official Docs**: https://doc.traefik.io/traefik/
- **Dashboard**: http://nas:8080 or https://traefik.yourdomain.com
- **Key Features**:
  - Automatic SSL/TLS certificate management via Let's Encrypt
  - CloudFlare DNS challenge for wildcard certificates
  - Dynamic service discovery
  - Middleware support (auth, rate limiting, compression)
  - Prometheus metrics export

#### 2. Authelia - Authentication & Authorization Server
- **Purpose**: Single Sign-On (SSO) and Two-Factor Authentication (2FA)
- **Official Docs**: https://www.authelia.com/
- **Dashboard**: https://auth.yourdomain.com
- **Key Features**:
  - TOTP-based 2FA (Google Authenticator, Authy compatible)
  - User/group-based access control
  - Session management with configurable timeouts
  - Brute-force protection
  - LDAP/Active Directory support (optional)

#### 3. WireGuard - VPN Server
- **Purpose**: Secure remote access to your network
- **Official Docs**: https://www.wireguard.com/
- **Port**: 51820/UDP
- **Key Features**:
  - Modern, fast VPN protocol (faster than OpenVPN)
  - Easy mobile app setup (iOS/Android)
  - Automatic peer configuration
  - DNS routing through AdGuard
  - Kill-switch compatible

#### 4. Vaultwarden - Password Manager
- **Purpose**: Self-hosted password vault (Bitwarden-compatible)
- **Official Docs**: https://github.com/dani-garcia/vaultwarden/wiki
- **Dashboard**: https://vault.yourdomain.com
- **Key Features**:
  - Compatible with all Bitwarden clients
  - Browser extensions (Chrome, Firefox, Edge, Safari)
  - TOTP generator built-in
  - Secure password sharing
  - Encrypted file attachments
  - Emergency access features

#### 5. Pi-hole - Network-Wide Ad Blocker
- **Purpose**: DNS-based ad blocking and privacy protection
- **Official Docs**: https://docs.pi-hole.net/
- **Dashboard**: http://nas:8053 or https://dns.yourdomain.com
- **Key Features**:
  - Block ads, trackers, and malware domains across entire network
  - Extensive blocklist library and custom list support
  - Detailed query logging and statistics dashboard
  - Per-device blocking controls
  - DHCP server (optional)
  - Web interface with real-time analytics

</details>

### 📁 Productivity & Storage (1 Service)

<details>
<summary><b>Click to expand Productivity Services details</b></summary>

#### 6. Nextcloud - Personal Cloud Platform
- **Purpose**: File sync, sharing, calendar, contacts, and collaboration
- **Official Docs**: https://docs.nextcloud.com/
- **Dashboard**: https://cloud.yourdomain.com
- **Key Features**:
  - Dropbox/Google Drive alternative
  - End-to-end encryption
  - Calendar (CalDAV) and Contacts (CardDAV)
  - Real-time document collaboration (via Collabora/OnlyOffice)
  - Mobile apps (iOS/Android)
  - Desktop sync clients (Windows/Mac/Linux)
  - Extensive app ecosystem (Mail, Talk, Notes, Tasks, etc.)
  - External storage support (S3, Google Drive, FTP)
- **Database**: MariaDB (included)
- **Recommended Apps**:
  - Nextcloud Office (OnlyOffice integration)
  - Nextcloud Talk (video calls)
  - Nextcloud Mail
  - External Storage Support
  - Two-Factor TOTP Provider

</details>

### 📊 Monitoring & Management Layer (4 Services)

<details>
<summary><b>Click to expand Monitoring Services details</b></summary>

#### 7. Portainer - Container Management UI
- **Purpose**: Visual Docker management interface
- **Official Docs**: https://docs.portainer.io/
- **Dashboard**: http://nas:9000 or https://portainer.yourdomain.com
- **Key Features**:
  - Visual container management
  - Stack deployment (docker-compose)
  - Real-time logs and stats
  - User management and RBAC
  - Template library
  - Registry management

#### 8. Uptime Kuma - Uptime Monitoring
- **Purpose**: Service availability monitoring and alerting
- **Official Docs**: https://github.com/louislam/uptime-kuma/wiki
- **Dashboard**: https://status.yourdomain.com
- **Key Features**:
  - HTTP(s), TCP, Ping monitoring
  - Status pages (public/private)
  - Multi-notification channels (email, Slack, Discord, Telegram)
  - Certificate expiry monitoring
  - Response time tracking
  - Beautiful, modern UI

#### 9. Grafana - Metrics Visualization
- **Purpose**: Data visualization and analytics
- **Official Docs**: https://grafana.com/docs/
- **Dashboard**: https://grafana.yourdomain.com
- **Key Features**:
  - Pre-built dashboards for Docker, system metrics
  - Alerting rules
  - Multiple data source support
  - Custom dashboard creation
  - Panel plugins ecosystem
  - Screenshot/PDF export

#### 10. Prometheus - Metrics Collection
- **Purpose**: Time-series database and monitoring system
- **Official Docs**: https://prometheus.io/docs/
- **Port**: 9090 (internal only)
- **Key Features**:
  - Multi-dimensional data model
  - PromQL query language
  - Service discovery
  - Alerting via Alertmanager (optional)
  - 30-day data retention (configurable)
  - Efficient storage

#### 11. cAdvisor - Container Metrics Exporter
- **Purpose**: Container resource usage metrics for Prometheus
- **Official Docs**: https://github.com/google/cadvisor
- **Key Features**:
  - CPU, memory, network, disk metrics per container
  - Real-time monitoring
  - Historical data collection
  - Low resource overhead
  - Prometheus-compatible export

</details>

### 🛠️ Utilities Layer (4 Services)

<details>
<summary><b>Click to expand Utility Services details</b></summary>

#### 12. Homepage - Dashboard & Portal
- **Purpose**: Centralized dashboard for all services
- **Official Docs**: https://gethomepage.dev/
- **Dashboard**: https://yourdomain.com or https://home.yourdomain.com
- **Key Features**:
  - Beautiful, customizable dashboard
  - Service status widgets
  - Weather, date/time widgets
  - Docker integration
  - Bookmarks and search
  - Mobile-responsive

#### 13. Diun - Docker Image Update Notifier
- **Purpose**: Automated container update notifications
- **Official Docs**: https://crazymax.dev/diun/
- **Key Features**:
  - Scans all containers for updates
  - Configurable scan schedule
  - Multiple notification channels
  - Docker Hub rate limit aware
  - Registry authentication support

#### 14. Dozzle - Real-Time Log Viewer
- **Purpose**: Web-based Docker log viewer
- **Official Docs**: https://dozzle.dev/
- **Dashboard**: https://logs.yourdomain.com
- **Key Features**:
  - Real-time log streaming
  - No database required
  - Search and filter logs
  - Multi-container view
  - Color-coded log levels
  - Extremely lightweight

#### 15. IT-Tools - Developer Utilities Collection
- **Purpose**: Handy tools for developers and sysadmins
- **Official Docs**: https://github.com/CorentinTh/it-tools
- **Dashboard**: https://tools.yourdomain.com
- **Key Features**:
  - 50+ useful tools
  - Base64 encoder/decoder
  - JSON formatter and validator
  - Hash generators (MD5, SHA, etc.)
  - QR code generator
  - UUID generator
  - And many more...

</details>

---

## 🏗️ System Architecture

### Network Topology

```
Internet
    ↓
[Router] → Port Forwarding (80, 443, 51820)
    ↓
[Synology NAS - 192.168.1.100]
    ↓
[Traefik Reverse Proxy] ← SSL Certificates (Let's Encrypt)
    ↓
├─[Proxy Network]───────────────────────────┐
│  ├─ Authelia (2FA Gateway)                │
│  ├─ Vaultwarden                           │
│  ├─ Pi-hole                               │
│  ├─ Nextcloud                             │
│  ├─ Portainer                             │
│  ├─ Uptime Kuma                           │
│  ├─ Grafana                               │
│  ├─ Homepage                              │
│  ├─ Dozzle                                │
│  └─ IT-Tools                              │
│                                            │
├─[Storage Network (Isolated)]──────────────┤
│  ├─ Nextcloud Database (MariaDB)          │
│  └─ Redis (if needed)                     │
│                                            │
├─[Monitoring Network (Isolated)]───────────┤
│  ├─ Prometheus                            │
│  ├─ cAdvisor                              │
│  └─ Grafana                               │
│                                            │
└─[Internal Network (No External Access)]───┘
   └─ Prometheus (scraping only)
```

### Data Flow

```
User Request → Traefik → Authelia (2FA) → Service → Response
                  ↓
            [SSL Offload]
                  ↓
            [Rate Limiting]
                  ↓
          [Security Headers]
```

### Storage Architecture

```
/volume1/docker/synology-stack/
├── config/              # Service configurations
│   ├── traefik/        # Reverse proxy config
│   ├── authelia/       # 2FA config & user database
│   ├── prometheus/     # Metrics config
│   └── grafana/        # Dashboard config
├── data/               # Application data
│   ├── vaultwarden/    # Password vault database
│   ├── nextcloud/      # Nextcloud app data
│   ├── nextcloud-db/   # MariaDB data
│   └── uptime-kuma/    # Monitoring data
├── logs/               # Application logs
└── backups/            # Automated backups
```

---

## 🚀 Quick Start

### Prerequisites Checklist

- [ ] Synology DS 224+ (or compatible) with DSM 7.x
- [ ] 16GB RAM installed
- [ ] 50GB+ free disk space
- [ ] Static IP configured on NAS
- [ ] Domain name (or DuckDNS/No-IP dynamic DNS)
- [ ] CloudFlare account (free tier works)
- [ ] SSH access enabled
- [ ] Docker package installed from Package Center

### 5-Minute Setup

```bash
# 1. SSH into your Synology NAS
ssh admin@192.168.1.100

# 2. Navigate to Docker directory
cd /volume1/docker

# 3. Clone repository
git clone https://github.com/morandeirachema/synology_containers.git
cd synology_containers

# 4. Copy environment template
cp .env.example .env

# 5. Edit configuration (REQUIRED!)
nano .env

# 6. Create directories
chmod +x scripts/setup-directories.sh
./scripts/setup-directories.sh

# 7. Deploy stack
docker-compose up -d

# 8. Check status
docker-compose ps
```

### ⚡ Next Steps

1. Access **Portainer** at `http://YOUR_NAS_IP:9000` (create admin account within 5 min)
2. Configure **Authelia 2FA** at `https://auth.yourdomain.com`
3. Set up **Vaultwarden** at `https://vault.yourdomain.com`
4. Import **Grafana dashboards** from [Grafana.com](https://grafana.com/grafana/dashboards/)
5. Read the **[Complete Setup Guide](docs/SETUP.md)** for detailed instructions

---

## 💻 System Requirements

### Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **NAS Model** | DS 220+, DS 720+, DS 920+ | DS 224+, DS 923+, DS 1522+ | Any Synology with Docker support |
| **RAM** | 8GB | 16GB+ | Our stack uses ~6.5GB |
| **Storage** | 50GB free | 100GB+ SSD | SSD highly recommended for databases |
| **Network** | 100 Mbps | 1 Gbps | For external access and syncing |
| **CPU** | 2+ cores | 4+ cores | Intel Celeron J4125 or better |

### Software Requirements

- **DSM Version**: 7.0 or later (7.2+ recommended)
- **Docker Package**: Latest version from Synology Package Center
- **SSH**: Enabled (Control Panel → Terminal & SNMP)
- **Git**: Pre-installed on DSM 7.x

### Network Requirements

- **Static IP**: Assigned to your NAS
- **Port Forwarding**: Ports 80, 443, 51820 (UDP)
- **Domain Name**: For external access (or dynamic DNS)
- **CloudFlare Account**: For SSL certificates (free tier works)

### Resource Allocation (16GB RAM)

| Service | RAM Limit | CPU Limit | Disk Usage | Priority |
|---------|-----------|-----------|------------|----------|
| Traefik | 256 MB | 0.5 cores | ~1 GB | Normal |
| Authelia | 256 MB | 0.3 cores | ~1 GB | Normal |
| WireGuard | 128 MB | 0.5 cores | ~500 MB | High |
| Vaultwarden | 256 MB | 0.5 cores | ~2 GB | Normal |
| Pi-hole | 256 MB | 0.5 cores | ~1 GB | Normal |
| Nextcloud (App) | 2048 MB | 1.5 cores | Varies | High |
| Nextcloud (DB) | 512 MB | 0.5 cores | Varies | Normal |
| Portainer | 256 MB | 0.5 cores | ~1 GB | Low |
| Uptime Kuma | 256 MB | 0.5 cores | ~1 GB | Low |
| Grafana | 512 MB | 0.5 cores | ~2 GB | Normal |
| Prometheus | 1024 MB | 1.0 cores | ~10 GB | Normal |
| cAdvisor | 256 MB | 0.5 cores | ~500 MB | Normal |
| Homepage | 256 MB | 0.3 cores | ~500 MB | Low |
| Diun | 128 MB | 0.3 cores | ~100 MB | Low |
| Dozzle | 128 MB | 0.3 cores | ~100 MB | Low |
| IT-Tools | 128 MB | 0.3 cores | ~100 MB | Low |
| **TOTAL** | **~6.5 GB** | **~9 cores** | **~22 GB + Data** | - |

**Remaining Resources**: ~9.5GB RAM free for system operations and caching

---

## 📝 Installation Guide

### Step 1: Prepare Your Synology NAS

#### 1.1 Update DSM
```
Control Panel → Update & Restore → DSM Update → Check for Updates
```

#### 1.2 Install Docker
```
Package Center → Search "Docker" → Install
```

#### 1.3 Enable SSH
```
Control Panel → Terminal & SNMP
- [x] Enable SSH service
- Port: 22 (or custom port for security)
- Click Apply
```

#### 1.4 Configure Static IP
```
Control Panel → Network → Network Interface → LAN
- Manual configuration
- IP: 192.168.1.100 (example)
- Subnet: 255.255.255.0
- Gateway: 192.168.1.1 (your router)
- DNS: 1.1.1.1, 8.8.8.8
```

#### 1.5 Configure Firewall
```
Control Panel → Security → Firewall
- Create new profile
- Allow: Ports 80, 443, 51820 (UDP)
- Optional: Restrict SSH to local network only
```

### Step 2: Domain and DNS Setup

#### 2.1 Get a Domain
- **Purchase**: Namecheap, Google Domains, Cloudflare
- **Free Dynamic DNS**: DuckDNS.org, No-IP.com

#### 2.2 Setup CloudFlare (Recommended)
1. Create account at [CloudFlare.com](https://www.cloudflare.com/)
2. Add your domain
3. Update nameservers at your registrar
4. Wait for DNS propagation (up to 48 hours)

#### 2.3 Create DNS Records
```
Type: A
Name: @
Content: YOUR_PUBLIC_IP
Proxy: OFF (orange cloud disabled)
TTL: Auto

Type: CNAME
Name: *
Content: yourdomain.com
Proxy: OFF
TTL: Auto
```

#### 2.4 Get CloudFlare API Token
```
My Profile → API Tokens → Create Token
Template: "Edit zone DNS"
Zone Resources: Include → Specific zone → yourdomain.com
Continue → Create Token
SAVE THIS TOKEN SECURELY!
```

### Step 3: Router Configuration

#### 3.1 Port Forwarding
Configure these port forwards on your router:

| Service | External Port | Internal IP | Internal Port | Protocol |
|---------|---------------|-------------|---------------|----------|
| HTTP | 80 | 192.168.1.100 | 80 | TCP |
| HTTPS | 443 | 192.168.1.100 | 443 | TCP |
| WireGuard | 51820 | 192.168.1.100 | 51820 | UDP |

#### 3.2 Test Port Forwarding
- Use [PortChecker.co](https://portchecker.co/) to verify ports 80 and 443 are open

### Step 4: Clone and Configure

```bash
# SSH into NAS
ssh admin@192.168.1.100

# Navigate to Docker directory
cd /volume1/docker

# Clone repository
git clone https://github.com/morandeirachema/synology_containers.git
cd synology_containers

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### Step 5: Configure Environment Variables

Edit `.env` file with your values:

```bash
# Essential Configuration
TZ=America/New_York                    # Your timezone
DOMAIN=yourdomain.com                  # Your domain
NAS_IP=192.168.1.100                  # Your NAS IP

# CloudFlare (for SSL certificates)
CF_API_EMAIL=your-email@example.com
CF_DNS_API_TOKEN=your-cloudflare-api-token

# Generate Secrets
# Run: openssl rand -hex 32
AUTHELIA_JWT_SECRET=<generated-secret>
AUTHELIA_SESSION_SECRET=<generated-secret>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generated-secret>

# Run: openssl rand -base64 48
VAULTWARDEN_ADMIN_TOKEN=<generated-secret>

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<strong-password>
NEXTCLOUD_DB_PASSWORD=<strong-password>
NEXTCLOUD_DB_ROOT_PASSWORD=<strong-password>
NEXTCLOUD_DATA_PATH=/volume1/nextcloud-data

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<strong-password>

# SMTP (optional but recommended)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_FROM=noreply@yourdomain.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=<app-specific-password>

# WireGuard
WIREGUARD_SERVERURL=vpn.yourdomain.com
WIREGUARD_PEERS=laptop,phone,tablet
```

### Step 6: Create Storage Directories

```bash
# Create Nextcloud data directory
sudo mkdir -p /volume1/nextcloud-data
sudo chown -R 1000:1000 /volume1/nextcloud-data

# Run setup script
chmod +x scripts/setup-directories.sh
./scripts/setup-directories.sh
```

### Step 7: Update Configuration Files

#### 7.1 Traefik Configuration
```bash
nano config/traefik/traefik.yml
```
Update line 53: Change email to your actual email

#### 7.2 Authelia Configuration
```bash
nano config/authelia/configuration.yml
```
Replace all instances of `yourdomain.com` with your actual domain

#### 7.3 Create Authelia Admin User
```bash
# Generate password hash
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourSecurePassword'

# Edit users file
nano config/authelia/users_database.yml
# Replace the example hash with your generated hash
```

### Step 8: Deploy the Stack

```bash
# Validate configuration
docker-compose config

# Start services
docker-compose up -d

# Monitor deployment
docker-compose logs -f

# Check status (Ctrl+C to exit logs first)
docker-compose ps

# Run health check
./scripts/health-check.sh
```

### Step 9: Initial Service Configuration

#### 9.1 Portainer (First!)
1. Access `http://YOUR_NAS_IP:9000`
2. Create admin account (**within 5 minutes or restart container**)
3. Select "Local" environment
4. Explore container dashboard

#### 9.2 Authelia 2FA
1. Access `https://auth.yourdomain.com`
2. Login with credentials from users_database.yml
3. Setup 2FA (scan QR with Google Authenticator/Authy)
4. Save backup codes securely

#### 9.3 Vaultwarden
1. Access `https://vault.yourdomain.com`
2. Create your account
3. Access admin panel: `https://vault.yourdomain.com/admin`
4. Enter admin token from `.env`
5. Configure SMTP settings
6. Install browser extension

#### 9.4 Nextcloud
1. Access `https://cloud.yourdomain.com`
2. Login with admin credentials from `.env`
3. Install recommended apps
4. Configure background jobs (see docs/SETUP.md)

#### 9.5 Grafana
1. Access `https://grafana.yourdomain.com`
2. Login via Authelia
3. Verify Prometheus data source is connected
4. Import dashboards:
   - Dashboard ID 1860 (Node Exporter Full)
   - Dashboard ID 893 (Docker)
   - Dashboard ID 12705 (Traefik)

#### 9.6 Uptime Kuma
1. Access `https://status.yourdomain.com`
2. Create admin account
3. Add monitors for all services
4. Configure notification channels (email, Slack, Discord, etc.)

---

## ⚙️ Configuration

### Environment Variables Reference

<details>
<summary><b>Complete Environment Variables List</b></summary>

```bash
# Global Settings
TZ=America/New_York                    # Timezone (timedatectl list-timezones)
DOMAIN=yourdomain.com                  # Your domain name
NAS_IP=192.168.1.100                  # NAS static IP address

# CloudFlare DNS
CF_API_EMAIL=you@example.com          # CloudFlare account email
CF_DNS_API_TOKEN=xxxxx                # CloudFlare API token (DNS edit permission)

# Authelia Security
AUTHELIA_JWT_SECRET=xxxxx             # openssl rand -hex 32
AUTHELIA_SESSION_SECRET=xxxxx         # openssl rand -hex 32
AUTHELIA_STORAGE_ENCRYPTION_KEY=xxxxx # openssl rand -hex 32

# WireGuard VPN
WIREGUARD_SERVERURL=vpn.yourdomain.com # Your public IP or DDNS
WIREGUARD_PEERS=laptop,phone,tablet    # Comma-separated peer names

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=xxxxx         # openssl rand -base64 48

# SMTP Configuration (Optional)
SMTP_HOST=smtp.gmail.com              # SMTP server
SMTP_PORT=587                         # SMTP port
SMTP_SECURITY=starttls                # starttls or ssl
SMTP_FROM=noreply@yourdomain.com      # From address
SMTP_USERNAME=you@gmail.com           # SMTP username
SMTP_PASSWORD=xxxxx                   # App-specific password

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin            # Admin username
NEXTCLOUD_ADMIN_PASSWORD=xxxxx        # Strong password
NEXTCLOUD_DB_PASSWORD=xxxxx           # Database password
NEXTCLOUD_DB_ROOT_PASSWORD=xxxxx      # Database root password
NEXTCLOUD_DATA_PATH=/volume1/nextcloud-data # Data directory path

# Grafana
GRAFANA_ADMIN_USER=admin              # Admin username
GRAFANA_ADMIN_PASSWORD=xxxxx          # Strong password

# Diun (Optional)
GOTIFY_ENDPOINT=                      # Leave empty if not using
GOTIFY_TOKEN=                         # Leave empty if not using
```

</details>

### Service-Specific Configuration

<details>
<summary><b>Traefik Advanced Configuration</b></summary>

Edit `config/traefik/traefik.yml`:

```yaml
# Enable dashboard access
api:
  dashboard: true  # Set to false in production after setup
  insecure: false  # Never true in production

# Custom certificate resolver
certificatesResolvers:
  cloudflare:
    acme:
      email: your-email@example.com
      storage: /acme/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
        delayBeforeCheck: 30s  # Increase if DNS propagation is slow
```

**Middlewares** (`config/traefik/dynamic/middlewares.yml`):
- Security headers (HSTS, CSP, etc.)
- Rate limiting (prevent DDoS)
- IP whitelisting (restrict access)
- Compression (reduce bandwidth)

</details>

<details>
<summary><b>Authelia Access Control Rules</b></summary>

Edit `config/authelia/configuration.yml`:

```yaml
access_control:
  default_policy: deny  # Secure by default

  rules:
    # Bypass auth for Authelia itself
    - domain: 'auth.yourdomain.com'
      policy: bypass

    # Public status page
    - domain: 'status.yourdomain.com'
      policy: bypass
      networks:
        - '192.168.1.0/24'  # Local network only

    # Admin services require 2FA
    - domain:
        - 'portainer.yourdomain.com'
        - 'grafana.yourdomain.com'
        - 'traefik.yourdomain.com'
      policy: two_factor
      subject:
        - 'group:admins'

    # All other services require 2FA
    - domain: '*.yourdomain.com'
      policy: two_factor
```

</details>

<details>
<summary><b>Prometheus Scrape Configuration</b></summary>

Edit `config/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Traefik metrics
  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']

  # Docker container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Authelia metrics
  - job_name: 'authelia'
    static_configs:
      - targets: ['authelia:9959']
```

</details>

---

## 🌐 Service Access Points

### Default Access URLs

| Service | Local Access | External Access (HTTPS) | Auth Required |
|---------|--------------|------------------------|---------------|
| **Homepage** | N/A | `https://yourdomain.com`<br>`https://home.yourdomain.com` | ✅ 2FA |
| **Portainer** | `http://nas:9000` | `https://portainer.yourdomain.com` | Own auth |
| **Nextcloud** | N/A | `https://cloud.yourdomain.com` | Own auth |
| **Vaultwarden** | N/A | `https://vault.yourdomain.com` | Own auth |
| **Pi-hole** | `http://nas:8053` | `https://dns.yourdomain.com` | ✅ 2FA |
| **Grafana** | N/A | `https://grafana.yourdomain.com` | ✅ 2FA |
| **Uptime Kuma** | N/A | `https://status.yourdomain.com` | Own auth |
| **Dozzle** | N/A | `https://logs.yourdomain.com` | ✅ 2FA |
| **IT-Tools** | N/A | `https://tools.yourdomain.com` | ✅ 2FA |
| **Authelia** | N/A | `https://auth.yourdomain.com` | N/A |
| **Traefik Dashboard** | `http://nas:8080` | `https://traefik.yourdomain.com` | ✅ 2FA |

### Mobile App Support

| Service | iOS App | Android App | Notes |
|---------|---------|-------------|-------|
| Nextcloud | ✅ [App Store](https://apps.apple.com/app/nextcloud/id1125420102) | ✅ [Play Store](https://play.google.com/store/apps/details?id=com.nextcloud.client) | Full sync support |
| Vaultwarden | ✅ [Bitwarden](https://apps.apple.com/app/bitwarden/id1137397744) | ✅ [Bitwarden](https://play.google.com/store/apps/details?id=com.x8bit.bitwarden) | Use custom server URL |
| WireGuard | ✅ [App Store](https://apps.apple.com/app/wireguard/id1441195209) | ✅ [Play Store](https://play.google.com/store/apps/details?id=com.wireguard.android) | Import config via QR |
| Uptime Kuma | ✅ PWA | ✅ PWA | Install as PWA |

---

## 🔐 Security & Privacy

### Security Scorecard

| Category | Rating | Details |
|----------|--------|---------|
| **SSL/TLS** | A+ | Let's Encrypt, TLS 1.2+, Perfect Forward Secrecy |
| **Headers** | A+ | HSTS, CSP, X-Frame-Options, X-Content-Type-Options |
| **Authentication** | A+ | 2FA on all services, strong password policies |
| **Network** | A+ | Segmented networks, no unnecessary port exposure |
| **Updates** | A+ | Automated update notifications, version pinning |
| **Secrets** | A+ | Environment variables, no hardcoded credentials |
| **Encryption** | A+ | Data at rest and in transit |

### Security Features Implemented

#### 🔒 Transport Security
- **HTTPS Everywhere**: All traffic encrypted with TLS 1.2+
- **HSTS Enabled**: Strict Transport Security with preloading
- **Certificate Auto-Renewal**: Let's Encrypt certificates renewed automatically
- **Wildcard Certificates**: Single certificate for all subdomains

#### 🛡️ Authentication & Authorization
- **Two-Factor Authentication**: TOTP-based 2FA on all services
- **Single Sign-On**: Authelia provides SSO across services
- **Session Management**: Configurable timeouts and remember-me
- **Brute-Force Protection**: Failed login attempt limiting
- **Account Lockout**: Automatic lockout after failed attempts

#### 🌐 Network Security
- **Network Segmentation**: Services isolated in separate networks
- **Internal Networks**: Databases on non-routable networks
- **No Root Containers**: All services run as unprivileged users
- **Resource Limits**: Prevent resource exhaustion attacks
- **Rate Limiting**: Traefik middleware prevents abuse

#### 🔑 Secret Management
- **Environment Variables**: All secrets in .env (never committed)
- **Strong Password Generation**: OpenSSL random generation
- **Rotation Policy**: Guidelines for secret rotation
- **Vault Integration Ready**: Compatible with HashiCorp Vault

### Security Best Practices

<details>
<summary><b>Click for detailed security recommendations</b></summary>

#### Password Policy
- **Minimum Length**: 16 characters
- **Complexity**: Mix of upper, lower, numbers, symbols
- **Unique Passwords**: Different for each service
- **Generator**: Use Vaultwarden's built-in generator
- **Storage**: Store in Vaultwarden, never plaintext

#### Network Configuration
```bash
# Firewall rules on Synology
Control Panel → Security → Firewall

# Allow only necessary ports:
- 80/TCP (HTTP → HTTPS redirect)
- 443/TCP (HTTPS)
- 51820/UDP (WireGuard)

# Restrict SSH to local network:
- 22/TCP from 192.168.1.0/24 only

# Deny all other incoming traffic
```

#### Regular Security Tasks

**Weekly:**
- Review Authelia failed authentication logs
- Check Uptime Kuma for service disruptions
- Review Traefik access logs for unusual patterns

**Monthly:**
- Update all containers (use `./scripts/update-all.sh`)
- Rotate sensitive credentials
- Review user access permissions
- Check for security advisories

**Quarterly:**
- Full security audit
- Penetration testing (if applicable)
- Review and update documentation
- Backup testing and verification

#### Vulnerability Scanning

```bash
# Install Trivy
wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz
tar zxvf trivy_Linux-64bit.tar.gz

# Scan all images
docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
  echo "Scanning $image..."
  ./trivy image --severity HIGH,CRITICAL $image
done
```

</details>

### Security Resources

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **CIS Docker Benchmark**: https://www.cisecurity.org/benchmark/docker
- **Docker Security Best Practices**: https://docs.docker.com/engine/security/
- **Let's Encrypt Documentation**: https://letsencrypt.org/docs/
- **Authelia Security**: https://www.authelia.com/overview/security/

---

## ⚡ Performance Optimization

### System Optimization

<details>
<summary><b>Synology DSM Optimizations</b></summary>

#### Enable SSD Cache
```
Storage Manager → SSD Cache → Create → Read-Write Cache
- Select SSD drives
- Allocate cache space
- Enable "Skip sequential I/O"
```

#### Disable Unnecessary Services
```
Control Panel → Task Scheduler → Disable:
- Universal Search indexing (if not used)
- Thumbnail generation (if not needed)
- SMB multichannel (if on single network)
```

#### Optimize Docker Settings
```
# Edit /var/packages/Docker/etc/dockerd.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}

# Restart Docker
sudo synoservicectl --restart pkgctl-Docker
```

</details>

### Database Optimization

<details>
<summary><b>PostgreSQL Tuning</b></summary>

For services using PostgreSQL, add these to `docker-compose.yml`:

```yaml
command:
  - "postgres"
  - "-c"
  - "shared_buffers=256MB"
  - "-c"
  - "effective_cache_size=1GB"
  - "-c"
  - "maintenance_work_mem=64MB"
  - "-c"
  - "checkpoint_completion_target=0.9"
  - "-c"
  - "wal_buffers=16MB"
  - "-c"
  - "default_statistics_target=100"
  - "-c"
  - "random_page_cost=1.1"
  - "-c"
  - "effective_io_concurrency=200"
  - "-c"
  - "work_mem=2621kB"
  - "-c"
  - "min_wal_size=1GB"
  - "-c"
  - "max_wal_size=4GB"
```

</details>

<details>
<summary><b>MariaDB Tuning (Nextcloud)</b></summary>

```yaml
command:
  - "--innodb-buffer-pool-size=512M"
  - "--max-connections=200"
  - "--innodb-flush-log-at-trx-commit=2"
  - "--innodb-flush-method=O_DIRECT"
  - "--innodb-log-buffer-size=16M"
  - "--query-cache-size=0"
  - "--query-cache-type=0"
  - "--thread-cache-size=50"
```

</details>

### Nextcloud Specific Optimizations

```bash
# Connect to Nextcloud container
docker exec -u www-data nextcloud php occ

# Install and configure APCu
occ config:system:set memcache.local --value='\OC\Memcache\APCu'

# Configure Redis for file locking
occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
occ config:system:set redis host --value='nextcloud-redis'
occ config:system:set redis port --value=6379

# Optimize database
occ db:add-missing-indices
occ db:add-missing-columns
occ db:add-missing-primary-keys
occ db:convert-filecache-bigint

# Configure background jobs
occ background:cron
```

### Monitoring Performance

```bash
# Real-time resource monitoring
docker stats

# Check disk I/O
iostat -x 1

# Network monitoring
iftop

# Container-specific metrics
docker exec prometheus wget -qO- http://localhost:9090/metrics
```

---

## 💾 Backup & Recovery

### Automated Backup System

This stack includes a comprehensive backup solution:

#### Backup Script Features
- **Automated Daily Backups**: Via cron or Task Scheduler
- **30-Day Retention**: Automatic cleanup of old backups
- **Incremental Backups**: Only changed files
- **Database Dumps**: Dedicated database backups
- **Configuration Backups**: All service configs
- **Compressed Archives**: Gzip compression
- **Off-Site Ready**: Compatible with rsync, rclone

#### Running Backups

```bash
# Manual backup
cd /volume1/docker/synology_containers
./scripts/backup.sh

# Automated via DSM Task Scheduler
Control Panel → Task Scheduler → Create → Scheduled Task → User-defined script

# Daily at 2 AM:
Task: Daily Backup
User: root
Schedule: Daily 02:00
Script: /volume1/docker/synology_containers/scripts/backup.sh
```

#### What Gets Backed Up

1. **Environment Configuration** (`.env`)
2. **Docker Compose File** (`docker-compose.yml`)
3. **Service Configurations** (`config/` directory)
4. **Database Dumps**:
   - Nextcloud (MariaDB)
   - Vaultwarden (SQLite)
   - Authelia (SQLite)
5. **Application Data**:
   - Vaultwarden vault
   - Uptime Kuma monitoring data
   - Grafana dashboards
   - Prometheus data (optional)

### Backup Locations

```
/volume1/docker/backups/
├── synology-stack-backup_20250123_020000.tar.gz
├── synology-stack-backup_20250124_020000.tar.gz
└── synology-stack-backup_20250125_020000.tar.gz
```

### Off-Site Backup Options

<details>
<summary><b>Synology Hyper Backup</b></summary>

```
Package Center → Install "Hyper Backup"

Create Backup Task:
1. Destination: Cloud storage (Google Drive, Dropbox, S3, etc.)
2. Source: /volume1/docker/backups
3. Schedule: Daily after local backup (3 AM)
4. Enable versioning
5. Enable encryption
```

</details>

<details>
<summary><b>Rsync to Remote Server</b></summary>

```bash
#!/bin/bash
# Add to backup script

# Variables
REMOTE_USER="backupuser"
REMOTE_HOST="backup.server.com"
REMOTE_PATH="/backups/synology/"

# Sync backups
rsync -avz --delete \
  /volume1/docker/backups/ \
  ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}
```

</details>

<details>
<summary><b>Rclone to Cloud Storage</b></summary>

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure rclone (interactive)
rclone config

# Create sync script
#!/bin/bash
rclone sync /volume1/docker/backups/ mycloud:synology-backups \
  --progress \
  --transfers 4 \
  --checkers 8 \
  --retries 3
```

</details>

### Disaster Recovery

#### Complete System Restore

```bash
# 1. Fresh install of stack
cd /volume1/docker
git clone https://github.com/morandeirachema/synology_containers.git
cd synology_containers

# 2. Extract latest backup
tar -xzf /volume1/docker/backups/synology-stack-backup_LATEST.tar.gz

# 3. Restore configuration
cp backup/.env .env
cp backup/docker-compose.yml docker-compose.yml
cp -r backup/config/* config/

# 4. Start stack
docker-compose up -d

# 5. Restore databases
docker exec -i nextcloud-db mysql -u nextcloud -p${NEXTCLOUD_DB_PASSWORD} nextcloud < backup/nextcloud-db.sql

# 6. Verify all services
./scripts/health-check.sh
```

#### Individual Service Restore

```bash
# Restore Vaultwarden only
docker-compose stop vaultwarden
cp backup/vaultwarden.tar.gz .
tar -xzf vaultwarden.tar.gz -C data/
docker-compose start vaultwarden
```

### Backup Testing

**Monthly Backup Test Procedure:**

1. Stop one non-critical service (e.g., Uptime Kuma)
2. Delete its data directory
3. Restore from latest backup
4. Verify service functionality
5. Document any issues

---

## 📊 Monitoring & Maintenance

### Dashboard Overview

#### Homepage - Central Dashboard
- **URL**: `https://yourdomain.com`
- **Features**: Quick access to all services, status widgets
- **Customization**: Edit `config/homepage/services.yaml`

#### Portainer - Container Management
- **URL**: `https://portainer.yourdomain.com`
- **Features**:
  - Start/stop/restart containers
  - View logs
  - Access container shells
  - Deploy stacks
  - Monitor resources

#### Grafana - Metrics Visualization
- **URL**: `https://grafana.yourdomain.com`
- **Pre-configured Dashboards**:
  - Docker Container Overview
  - System Metrics (CPU, RAM, Disk)
  - Traefik Dashboard
  - Network Traffic

#### Uptime Kuma - Service Monitoring
- **URL**: `https://status.yourdomain.com`
- **Monitors**:
  - HTTP(S) endpoints
  - TCP ports
  - Ping monitoring
  - Certificate expiration
  - Response time tracking

### Monitoring Best Practices

<details>
<summary><b>Alert Configuration</b></summary>

#### Uptime Kuma Alerts

**Critical Alerts (Immediate Notification):**
- Any service down > 2 minutes
- SSL certificate expires < 7 days
- Disk space > 90%
- Memory usage > 85%

**Warning Alerts (Review Required):**
- Service response time > 5 seconds
- Failed backup jobs
- Container restarts
- Disk space > 75%

**Notification Channels:**
- Email (primary)
- Telegram/Discord (instant)
- Slack (team notifications)
- Webhook (integration with other tools)

</details>

### Maintenance Schedule

<details>
<summary><b>Daily Tasks (Automated)</b></summary>

```bash
# Automated via cron/Task Scheduler
0 2 * * * /volume1/docker/synology_containers/scripts/backup.sh
0 3 * * * /volume1/docker/synology_containers/scripts/cleanup-logs.sh
```

</details>

<details>
<summary><b>Weekly Tasks (15 minutes)</b></summary>

- [ ] Review Uptime Kuma dashboard for any downtime
- [ ] Check Grafana metrics for resource trends
- [ ] Review Authelia logs for failed authentication attempts
- [ ] Check for container updates via Diun notifications
- [ ] Verify backup completion
- [ ] Review disk space usage

</details>

<details>
<summary><b>Monthly Tasks (1 hour)</b></summary>

- [ ] Update all containers: `./scripts/update-all.sh`
- [ ] Test backup restoration
- [ ] Review and rotate credentials
- [ ] Check for security advisories
- [ ] Clean up old Docker images: `docker system prune -a`
- [ ] Review user access permissions
- [ ] Update documentation if changes made

</details>

<details>
<summary><b>Quarterly Tasks (2 hours)</b></summary>

- [ ] Full security audit
- [ ] Review and update Traefik/Authelia configurations
- [ ] Capacity planning (disk, RAM, CPU trends)
- [ ] Review monitoring alert thresholds
- [ ] Update SSL certificates manually if needed
- [ ] Performance optimization review
- [ ] Disaster recovery drill

</details>

### Update Management

#### Checking for Updates

```bash
# Check for available updates
cd /volume1/docker/synology_containers
./scripts/check-updates.sh

# Or view Diun notifications in logs
docker-compose logs diun
```

#### Updating Services

```bash
# Update all services safely
./scripts/update-all.sh

# This script:
# 1. Creates backup
# 2. Pulls new images
# 3. Recreates containers
# 4. Verifies health
# 5. Cleans old images
```

#### Updating Individual Services

```bash
# Update single service
docker-compose pull servicename
docker-compose up -d servicename

# Verify
docker-compose ps servicename
docker-compose logs -f servicename
```

---

## 🔧 Troubleshooting

### Common Issues & Solutions

<details>
<summary><b>Traefik Can't Get SSL Certificates</b></summary>

**Symptoms:**
- Browser shows "Certificate Invalid" error
- Traefik logs show ACME errors

**Solutions:**

1. **Verify DNS Configuration:**
   ```bash
   nslookup yourdomain.com
   # Should return your public IP
   ```

2. **Check CloudFlare API Token:**
   ```bash
   # Test API token
   curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer YOUR_API_TOKEN"
   ```

3. **Verify Port Forwarding:**
   - Ports 80 and 443 must be forwarded to your NAS
   - Test at [PortChecker.co](https://portchecker.co/)

4. **Check Rate Limits:**
   - Let's Encrypt has rate limits (50 certs/week per domain)
   - Use staging environment for testing

5. **Reset ACME:**
   ```bash
   docker-compose stop traefik
   rm config/traefik/acme/acme.json
   touch config/traefik/acme/acme.json
   chmod 600 config/traefik/acme/acme.json
   docker-compose up -d traefik
   docker-compose logs -f traefik
   ```

</details>

<details>
<summary><b>Container Won't Start</b></summary>

**Diagnosis:**
```bash
# Check container status
docker-compose ps servicename

# View logs
docker-compose logs servicename

# Check for port conflicts
sudo netstat -tulpn | grep PORT

# Inspect container
docker inspect servicename
```

**Common Causes:**
1. **Port Already in Use**: Change port in docker-compose.yml
2. **Permission Issues**: `sudo chown -R 1000:1000 config/servicename data/servicename`
3. **Missing Environment Variable**: Check .env file
4. **Resource Limits**: Increase mem_limit in docker-compose.yml
5. **Volume Mount Issues**: Verify paths exist and are accessible

</details>

<details>
<summary><b>Can't Access Services Externally</b></summary>

**Checklist:**
- [ ] DNS points to public IP
- [ ] Ports 80/443 forwarded to NAS
- [ ] Firewall allows ports 80/443
- [ ] Traefik container running
- [ ] SSL certificates obtained
- [ ] Service has correct labels in docker-compose.yml

**Debugging:**
```bash
# Check Traefik routing
docker-compose logs traefik | grep "Adding route"

# Test from external network (mobile data)
curl -I https://yourdomain.com

# Check Traefik dashboard
http://YOUR_NAS_IP:8080
```

</details>

<details>
<summary><b>Nextcloud Connection Issues</b></summary>

**Trusted Domains Error:**
```bash
# Add trusted domain
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=cloud.yourdomain.com

# Verify
docker exec -u www-data nextcloud php occ config:system:get trusted_domains
```

**Database Connection Error:**
```bash
# Check database is running
docker-compose ps nextcloud-db

# Verify password in .env matches
grep NEXTCLOUD_DB_PASSWORD .env

# Restart both services
docker-compose restart nextcloud nextcloud-db
```

</details>

<details>
<summary><b>High Memory Usage</b></summary>

**Diagnosis:**
```bash
# Check memory usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Check system memory
free -h
```

**Solutions:**
1. Adjust memory limits in docker-compose.yml
2. Restart memory-hungry containers
3. Enable swap if disabled
4. Clean Docker system: `docker system prune -a`

</details>

### Getting Help

**Before asking for help, collect this information:**

```bash
# System info
uname -a
cat /etc/*release*

# Docker info
docker --version
docker-compose --version

# Container status
docker-compose ps

# Recent logs
docker-compose logs --tail=100 > debug.log

# Configuration (remove secrets first!)
docker-compose config > config.txt
```

**Where to get help:**
- 📖 Check [Documentation](docs/)
- 🐛 Search [GitHub Issues](https://github.com/morandeirachema/synology_containers/issues)
- 💬 Ask in [Discussions](https://github.com/morandeirachema/synology_containers/discussions)
- 🌐 Synology Community Forums
- 📚 Service-specific documentation (links in Service Catalog)

---

## 📚 Documentation

### Complete Documentation Set

| Document | Description | Link |
|----------|-------------|------|
| **Setup Guide** | Step-by-step installation instructions | [docs/SETUP.md](docs/SETUP.md) |
| **Security Hardening** | A+ security configuration guide | [docs/SECURITY.md](docs/SECURITY.md) |
| **Best Practices** | Production deployment guidelines | [docs/BEST_PRACTICES.md](docs/BEST_PRACTICES.md) |
| **Troubleshooting** | Common issues and solutions | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

### External Resources

#### Official Documentation
- **Synology DSM**: https://kb.synology.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Traefik**: https://doc.traefik.io/traefik/
- **Authelia**: https://www.authelia.com/
- **WireGuard**: https://www.wireguard.com/
- **Nextcloud**: https://docs.nextcloud.com/
- **Vaultwarden**: https://github.com/dani-garcia/vaultwarden/wiki
- **Grafana**: https://grafana.com/docs/
- **Prometheus**: https://prometheus.io/docs/

#### Community Resources
- **r/synology**: https://reddit.com/r/synology
- **r/selfhosted**: https://reddit.com/r/selfhosted
- **r/homelab**: https://reddit.com/r/homelab
- **LinuxServer.io Forums**: https://forums.unraid.net/
- **Docker Community**: https://forums.docker.com/

#### Learning Resources
- **Docker Mastery Course**: https://www.udemy.com/course/docker-mastery/
- **Synology Academy**: https://www.synology.com/en-global/dsm/software_spec/synology_academy
- **Traefik Labs**: https://traefik.io/resources/
- **Self-Hosting Guide**: https://github.com/awesome-selfhosted/awesome-selfhosted

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Can I use this on other Synology models?</b></summary>

Yes! This stack works on any Synology NAS that supports Docker:
- DS220+, DS720+, DS920+ (8GB+ RAM recommended)
- DS1522+, DS923+ (16GB+ RAM ideal)
- RS series (rack-mounted)

Adjust resource limits in `docker-compose.yml` based on available RAM.

</details>

<details>
<summary><b>Do I need a domain name?</b></summary>

**For local-only use**: No, you can access via IP addresses.

**For external access**: Yes, a domain is required for:
- SSL certificates (Let's Encrypt)
- Professional appearance
- Easier access

**Free alternatives**:
- DuckDNS.org (free dynamic DNS)
- No-IP.com
- Afraid.org

</details>

<details>
<summary><b>Can I add more services later?</b></summary>

Absolutely! This stack is designed to be modular. To add services:

1. Add service definition to `docker-compose.yml`
2. Add required environment variables to `.env`
3. Add Traefik labels for routing
4. Run `docker-compose up -d`

Popular additions:
- Jellyfin (media server)
- Sonarr/Radarr (media management)
- Transmission (torrents)
- Syncthing (file sync)
- Gitea (Git server)

</details>

<details>
<summary><b>How much does this cost to run?</b></summary>

**Hardware Costs:**
- Synology DS 224+: ~$300
- 16GB RAM upgrade: ~$60
- Total: ~$360 (one-time)

**Ongoing Costs:**
- Domain name: $10-15/year (optional)
- Electricity: ~$2-5/month (NAS is very efficient)
- CloudFlare: Free (Pro optional)
- Total: ~$10-20/year

**Savings** vs cloud services:
- Dropbox/Google Drive: $120/year
- 1Password/Bitwarden: $36/year
- VPN service: $60/year
- Total savings: ~$200/year

ROI: ~2 years

</details>

<details>
<summary><b>Is this secure enough for business use?</b></summary>

**For small business**: Yes, with proper maintenance:
- Regular updates
- Strong passwords
- 2FA enabled
- Regular backups
- Monitoring configured
- Security audits

**For enterprise**: Consider:
- Dedicated hardware
- Professional support
- Compliance requirements (GDPR, HIPAA, etc.)
- HA/failover setup
- Professional penetration testing

This stack follows industry best practices and achieves A+ security ratings.

</details>

<details>
<summary><b>What if I don't want 2FA on every service?</b></summary>

Edit `config/authelia/configuration.yml`:

```yaml
access_control:
  rules:
    # Bypass 2FA for specific services
    - domain:
        - 'service.yourdomain.com'
      policy: one_factor  # Password only

    # Or completely bypass (not recommended!)
    - domain:
        - 'service.yourdomain.com'
      policy: bypass
```

**Warning**: Only bypass 2FA for services with their own strong authentication.

</details>

<details>
<summary><b>Can I use this without CloudFlare?</b></summary>

Yes! Alternatives:

**Other DNS providers** (modify `config/traefik/traefik.yml`):
- Google Cloud DNS
- AWS Route53
- DigitalOcean
- OVH

**HTTP Challenge** (ports 80/443 must be accessible):
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      httpChallenge:
        entryPoint: web
```

**Manual certificates**: Use your own SSL certs.

</details>

<details>
<summary><b>How do I migrate from another setup?</b></summary>

**From other NAS** (QNAP, Unraid, etc.):
1. Export data from current services
2. Deploy this stack
3. Import data to new services

**From cloud services**:
- **Google Drive → Nextcloud**: Use Nextcloud migration tools
- **Bitwarden → Vaultwarden**: Export/import vault
- **LastPass → Vaultwarden**: Use conversion tools

**Migration assistance**: Check service-specific documentation.

</details>

---

## 💬 Support & Community

### Getting Support

<details>
<summary><b>Before Creating an Issue</b></summary>

1. **Search existing issues**: Your problem might already be solved
2. **Check documentation**: Review all docs in `docs/` folder
3. **Verify configuration**: Run `docker-compose config`
4. **Collect logs**: `docker-compose logs > debug.log`
5. **Check system resources**: `docker stats`, `free -h`, `df -h`

</details>

### Creating a Bug Report

**Include:**
- Synology model and DSM version
- Docker and docker-compose versions
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs
- Screenshots (if applicable)

**Template:**
```markdown
**Environment:**
- Synology Model: DS 224+
- DSM Version: 7.2
- Docker: 20.10.23
- Docker Compose: 2.5.0

**Issue:**
[Description]

**Steps to Reproduce:**
1.
2.
3.

**Logs:**
```
[Paste relevant logs]
```

**Screenshots:**
[If applicable]
```

### Feature Requests

We welcome feature requests! Please include:
- Use case description
- Proposed solution
- Alternative solutions considered
- Willingness to contribute (optional)

### Community Guidelines

- Be respectful and constructive
- Help others when you can
- Share your successful configurations
- Contribute documentation improvements
- Report security issues privately

### Contact

- **Issues**: [GitHub Issues](https://github.com/morandeirachema/synology_containers/issues)
- **Discussions**: [GitHub Discussions](https://github.com/morandeirachema/synology_containers/discussions)
- **Security**: Email maintainer privately

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Ways to Contribute

- 🐛 **Report Bugs**: Create detailed issue reports
- 💡 **Suggest Features**: Share your ideas
- 📖 **Improve Documentation**: Fix typos, add examples
- 🔧 **Submit Code**: Fix bugs, add features
- 🎨 **Improve UI**: Better configs, dashboards
- 🌍 **Translate**: Localize documentation
- ⭐ **Star the Repo**: Show your support!

### Development Setup

```bash
# Fork the repository
# Clone your fork
git clone https://github.com/YOUR_USERNAME/synology_containers.git
cd synology_containers

# Create feature branch
git checkout -b feature/amazing-feature

# Make changes
# Test thoroughly
# Commit with clear messages
git commit -m "Add amazing feature"

# Push to your fork
git push origin feature/amazing-feature

# Create Pull Request
```

### Contribution Guidelines

- Follow existing code style
- Test all changes thoroughly
- Update documentation
- Add yourself to CONTRIBUTORS.md
- Use clear commit messages
- Reference related issues

---

## 🗺️ Roadmap

### Completed Features ✅

- [x] Base stack with 12 essential services
- [x] Automatic HTTPS with Let's Encrypt
- [x] Two-factor authentication (Authelia)
- [x] Complete monitoring stack (Prometheus/Grafana)
- [x] Automated backup system
- [x] Comprehensive documentation
- [x] Health check scripts
- [x] Security hardening guide

### Planned Features 🚧

**Q1 2025:**
- [ ] Terraform/Ansible automation
- [ ] Pre-configured Grafana dashboards
- [ ] Integration tests suite
- [ ] Video tutorials

**Q2 2025:**
- [ ] High availability setup (multi-NAS)
- [ ] Advanced monitoring (Loki for logs)
- [ ] Kubernetes migration guide
- [ ] Mobile app for management

**Q3 2025:**
- [ ] AI-powered log analysis
- [ ] Automated security scanning
- [ ] Disaster recovery automation
- [ ] Performance benchmarking tools

**Community Requests:**
- [ ] One-click installer script
- [ ] Web-based configuration generator
- [ ] Optional services catalog
- [ ] Multi-language documentation

*Suggestions? [Open an issue](https://github.com/morandeirachema/synology_containers/issues)!*

---

## 📜 Changelog

### [1.1.0] - 2025-01-XX
**Changed:**
- Streamlined stack to 12 core services
- Removed home automation services (Home Assistant, Node-RED, Mosquitto)
- Removed resource-intensive services (Immich, Paperless-ngx)
- Reduced RAM usage from 11GB to 6.5GB
- Updated all documentation

### [1.0.0] - 2025-01-23
**Added:**
- Initial release with 20 services
- Complete documentation suite
- Automated backup scripts
- Security hardening configurations
- Monitoring stack (Prometheus/Grafana)
- Dashboard (Homepage)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**MIT License Summary:**
- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Private use allowed
- ❌ No liability
- ❌ No warranty

---

## 🙏 Acknowledgments

### Built With

This stack leverages these amazing open-source projects:

- [Docker](https://www.docker.com/) - Containerization platform
- [Traefik](https://traefik.io/) - Modern reverse proxy
- [Authelia](https://www.authelia.com/) - Authentication server
- [WireGuard](https://www.wireguard.com/) - VPN protocol
- [Nextcloud](https://nextcloud.com/) - Personal cloud
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - Password manager
- [Grafana](https://grafana.com/) - Observability platform
- [Prometheus](https://prometheus.io/) - Monitoring system
- [Portainer](https://www.portainer.io/) - Container management

### Inspiration

- [LinuxServer.io](https://www.linuxserver.io/) - Quality container images
- [Awesome-Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) - Self-hosting resources
- [r/selfhosted](https://reddit.com/r/selfhosted) - Community inspiration
- [SmartHomeBeginner](https://www.smarthomebeginner.com/) - Docker guides

### Contributors

Thanks to all contributors who help improve this project!

[View all contributors](https://github.com/morandeirachema/synology_containers/graphs/contributors)

---

## ⭐ Star History

If you find this project helpful, please consider giving it a star! ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=morandeirachema/synology_containers&type=Date)](https://star-history.com/#morandeirachema/synology_containers&Date)

---

<div align="center">

**Made with ❤️ for the self-hosting community**

[Report Bug](https://github.com/morandeirachema/synology_containers/issues) · [Request Feature](https://github.com/morandeirachema/synology_containers/issues) · [Discussions](https://github.com/morandeirachema/synology_containers/discussions)

**Don't forget to ⭐ this repo if you found it useful!**

</div>
