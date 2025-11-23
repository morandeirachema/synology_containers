# Synology DS 224+ Container Stack

A production-ready, security-focused container stack for Synology DS 224+ (16GB RAM) featuring 12 essential services for privacy, productivity, and monitoring.

## 🎯 Overview

This repository provides a complete Docker container setup optimized for Synology NAS, following industry best practices for security, performance, and maintainability.

### 12 Essential Services

#### 🔒 Security & Privacy
1. **Traefik** - Modern reverse proxy with automatic HTTPS (Let's Encrypt)
2. **Authelia** - 2FA/SSO authentication gateway
3. **WireGuard** - Fast, secure VPN for remote access
4. **Vaultwarden** - Self-hosted password manager (Bitwarden compatible)
5. **AdGuard Home** - Network-wide ad & tracker blocking

#### 📁 Productivity & Storage
6. **Nextcloud** - File sync, calendar, contacts, and collaboration

#### 📊 Monitoring & Management
7. **Portainer** - Container management interface
8. **Uptime Kuma** - Self-hosted uptime monitoring
9. **Grafana** - Metrics visualization and dashboards
10. **Prometheus** - Metrics collection and alerting
11. **cAdvisor** - Container resource metrics for Prometheus

#### 🛠️ Utilities
12. **Homepage** - Beautiful dashboard for all your services
13. **Diun** - Docker image update notifications
14. **Dozzle** - Real-time log viewer for Docker containers
15. **IT-Tools** - Collection of handy developer utilities

## 🚀 Quick Start

### Prerequisites

- Synology DS 224+ with DSM 7.x
- 16GB RAM installed
- Docker package installed via Package Center
- SSH access enabled
- Static IP configured on your NAS

### Installation

1. **SSH into your Synology NAS:**
   ```bash
   ssh admin@YOUR_NAS_IP
   ```

2. **Clone this repository:**
   ```bash
   cd /volume1/docker
   git clone <your-repo-url> synology-stack
   cd synology-stack
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   nano .env  # Edit with your values
   ```

4. **Create required directories:**
   ```bash
   ./scripts/setup-directories.sh
   ```

5. **Deploy the stack:**
   ```bash
   docker-compose up -d
   ```

6. **Access Portainer for management:**
   ```
   http://YOUR_NAS_IP:9000
   ```

## 📋 System Requirements

### Resource Allocation (16GB RAM)

| Service | RAM Limit | CPU Priority | Storage |
|---------|-----------|--------------|---------|
| Traefik | 256MB | Normal | 1GB |
| Authelia | 256MB | Normal | 1GB |
| WireGuard | 128MB | High | 500MB |
| Vaultwarden | 256MB | Normal | 2GB |
| AdGuard Home | 256MB | Normal | 1GB |
| Nextcloud | 2GB | High | Varies |
| Nextcloud DB | 512MB | Normal | Varies |
| Portainer | 256MB | Low | 1GB |
| Uptime Kuma | 256MB | Low | 1GB |
| Grafana | 512MB | Normal | 2GB |
| Prometheus | 1GB | Normal | 10GB |
| cAdvisor | 256MB | Normal | 500MB |
| Homepage | 256MB | Low | 500MB |
| Diun | 128MB | Low | 100MB |
| Dozzle | 128MB | Low | 100MB |
| IT-Tools | 128MB | Low | 100MB |
| **Total** | **~6.5GB** | - | **~22GB + Data** |

*Remaining ~9.5GB reserved for system and cache*

## 🔐 Security Features

- ✅ All services behind Traefik reverse proxy
- ✅ Automatic HTTPS with Let's Encrypt
- ✅ 2FA authentication via Authelia
- ✅ Secure VPN access with WireGuard
- ✅ Network isolation with Docker networks
- ✅ Non-root containers where possible
- ✅ Secret management via .env file
- ✅ Regular security updates automated
- ✅ Fail2ban integration ready
- ✅ CloudFlare tunnel compatible

## 📖 Documentation

- [Initial Setup Guide](docs/SETUP.md)
- [Service Configuration](docs/SERVICES.md)
- [Security Hardening](docs/SECURITY.md)
- [Backup & Restore](docs/BACKUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Best Practices](docs/BEST_PRACTICES.md)
- [Update Guide](docs/UPDATES.md)

## 🌐 Access Points

After deployment, services are accessible at:

| Service | Local URL | External URL (via Traefik) |
|---------|-----------|----------------------------|
| Homepage | - | https://yourdomain.com or https://home.yourdomain.com |
| Portainer | http://nas:9000 | https://portainer.yourdomain.com |
| Nextcloud | - | https://cloud.yourdomain.com |
| Vaultwarden | - | https://vault.yourdomain.com |
| Grafana | - | https://grafana.yourdomain.com |
| AdGuard | http://nas:3001 | https://dns.yourdomain.com |
| Uptime Kuma | - | https://status.yourdomain.com |
| Dozzle | - | https://logs.yourdomain.com |
| IT-Tools | - | https://tools.yourdomain.com |
| Authelia | - | https://auth.yourdomain.com |
| Traefik Dashboard | http://nas:8080 | https://traefik.yourdomain.com |

*Configure your domain in .env file. Services without local URL are accessed via Traefik only.*

## 🔧 Maintenance

### Daily Backups
```bash
./scripts/backup.sh
```

### Update All Containers
```bash
./scripts/update-all.sh
```

### Health Check
```bash
./scripts/health-check.sh
```

### View Logs
```bash
docker-compose logs -f [service-name]
```

## 💾 Backup Strategy

- **Automated daily backups** to `/volume1/docker/backups`
- **Database dumps** for all services with databases
- **Configuration backups** versioned and dated
- **Off-site backup** to external storage recommended
- **Restore scripts** included for disaster recovery

## 🆘 Support

- Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Review service logs: `docker-compose logs [service]`
- Validate configuration: `docker-compose config`
- Check resource usage in Portainer

## 📊 Performance Optimization

This stack is optimized for the DS 224+ with:
- Efficient resource limits preventing OOM issues
- SSD cache configuration support
- Database query optimization
- Image cleanup automation
- Log rotation configured
- Health checks for all critical services

## 🔄 Updates

All containers use specific version tags (not `latest`) for stability. Update individually or use the provided update script.

```bash
# Check for updates
./scripts/check-updates.sh

# Update specific service
docker-compose pull [service]
docker-compose up -d [service]
```

## 📝 License

MIT License - See LICENSE file

## 🙏 Acknowledgments

Built with best practices from:
- Docker official documentation
- Synology community forums
- LinuxServer.io images
- Security frameworks (OWASP, CIS)

## ⚠️ Important Notes

- Always test updates on a non-production setup first
- Keep DSM updated to the latest stable version
- Enable Synology Snapshot Replication for volume backups
- Configure UPS for graceful shutdowns
- Monitor disk health regularly
- Review logs weekly for security issues

---

**Repository Status:** Production Ready | Last Updated: 2025-11 | DSM 7.x Compatible
