# Best Practices for Synology Container Stack

## 🎯 Production Deployment

### Pre-Deployment Checklist

- [ ] Review and understand all services being deployed
- [ ] Change ALL default passwords in `.env` file
- [ ] Generate strong, unique secrets for all services
- [ ] Configure domain names and DNS records
- [ ] Set up CloudFlare (or DNS provider) API credentials
- [ ] Configure email SMTP settings for notifications
- [ ] Review resource limits in docker-compose.yml
- [ ] Plan backup strategy and storage locations
- [ ] Test backup and restore procedures
- [ ] Document custom configurations

### Security Best Practices

#### 1. Authentication & Access Control

**Strong Passwords:**
```bash
# Generate strong passwords
openssl rand -base64 32

# Generate for specific services
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR_PASSWORD'
```

**2FA Everywhere:**
- Enable 2FA via Authelia for all external services
- Use hardware keys (YubiKey) where possible
- Maintain backup 2FA codes in secure location

**Network Segmentation:**
- Keep services on isolated Docker networks
- Use `internal: true` for database networks
- Only expose necessary ports to host

#### 2. SSL/TLS Configuration

**Certificate Management:**
- Use Let's Encrypt via Traefik for automatic SSL
- Set appropriate certificate renewal intervals
- Monitor certificate expiration via Uptime Kuma

**Security Headers:**
```yaml
# Already configured in Traefik middlewares
- HSTS enabled (31536000 seconds)
- Content Security Policy
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
```

#### 3. Container Security

**Image Selection:**
- Use official images when available
- Pin specific version tags (never use `:latest`)
- Regularly check for security updates
- Verify image signatures when possible

**Runtime Security:**
```yaml
# Applied to all containers where applicable
security_opt:
  - no-new-privileges:true
read_only: true  # where feasible
```

**User Permissions:**
- Run containers as non-root user (PUID/PGID 1000)
- Apply principle of least privilege
- Limit container capabilities

### Resource Management

#### Memory Allocation (16GB Total)

**Critical Services (High Priority):**
- Home Assistant: 1GB
- Nextcloud: 2GB
- Immich: 2GB
- Prometheus: 1GB

**Standard Services:**
- Paperless: 1GB
- Grafana: 512MB
- Node-RED: 512MB

**Lightweight Services:**
- Traefik: 256MB
- Authelia: 256MB
- Vaultwarden: 256MB
- Pi-hole: 256MB
- Portainer: 256MB
- Uptime Kuma: 256MB

**Reserved:**
- System & Cache: ~6GB

#### CPU Management

**Best Practices:**
- Limit CPU usage to prevent single service monopolizing
- Higher priority for user-facing services
- Lower priority for monitoring/management tools

#### Storage Optimization

**SSD vs HDD:**
```
SSD (faster):
- Docker images and volumes
- Database files (PostgreSQL, MariaDB)
- Log files
- Configuration files

HDD (bulk storage):
- Media files (Nextcloud, Immich)
- Document archives (Paperless)
- Backups
```

### Backup Strategy

#### What to Backup

**Critical (Daily):**
- Environment configuration (`.env`)
- Service configurations (`config/`)
- Database dumps (all SQL databases)
- Authentication data (Authelia, Vaultwarden)

**Important (Weekly):**
- Application data
- User files (where not already backed up)
- Automation flows (Node-RED, Home Assistant)

**Optional (Monthly):**
- Metrics data (Prometheus - can be rebuilt)
- Logs (if needed for compliance)

#### Backup Locations

**3-2-1 Backup Rule:**
- 3 copies of data
- 2 different media types
- 1 off-site backup

**Implementation:**
```bash
# On NAS (primary)
/volume1/docker/backups/

# On external USB (secondary)
/volumeUSB1/backups/

# Cloud/remote (off-site)
rsync, rclone, or Synology Cloud Sync
```

#### Automated Backups

**Schedule via Synology Task Scheduler:**
```bash
# Daily at 2 AM
0 2 * * * /volume1/docker/synology-stack/scripts/backup.sh

# Weekly cleanup
0 3 * * 0 find /volume1/docker/backups -mtime +30 -delete
```

### Monitoring & Alerting

#### Key Metrics to Monitor

**System Level:**
- CPU usage per container
- Memory usage and available RAM
- Disk space (especially for logs and databases)
- Network throughput

**Application Level:**
- Container health status
- Response times
- Error rates
- Certificate expiration

**Security:**
- Failed authentication attempts
- Unusual traffic patterns
- Resource exhaustion attacks

#### Alert Configuration

**Critical Alerts (Immediate):**
- Any container down
- SSL certificate expiring <7 days
- Disk space >90%
- Memory usage >85%
- Failed backups

**Warning Alerts (Review):**
- High CPU usage (>80% sustained)
- Disk space >75%
- Failed login attempts >5 in 5 minutes

### Update Management

#### Update Strategy

**Testing First:**
1. Review changelog for breaking changes
2. Test in non-production environment if possible
3. Backup before any update
4. Update one service at a time for critical services

**Version Pinning:**
```yaml
# Good
image: nextcloud:28.0.1-apache

# Avoid
image: nextcloud:latest
image: nextcloud:28
```

**Update Schedule:**
- Security patches: ASAP (within 24-48 hours)
- Minor updates: Weekly/Bi-weekly
- Major updates: Monthly (after testing)

**Update Process:**
```bash
# Check for updates
docker-compose pull

# Backup first
./scripts/backup.sh

# Update specific service
docker-compose up -d --no-deps --build servicename

# Update all
./scripts/update-all.sh
```

### Performance Optimization

#### Docker Performance

**Storage Driver:**
- Use overlay2 (default on modern systems)
- Enable SSD caching in Synology

**Network Optimization:**
```yaml
# Use custom networks for better isolation
networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 1500
```

#### Database Optimization

**PostgreSQL:**
```yaml
command:
  - "postgres"
  - "-c"
  - "shared_buffers=256MB"
  - "-c"
  - "max_connections=200"
  - "-c"
  - "work_mem=4MB"
```

**MariaDB:**
```yaml
command:
  - "--innodb-buffer-pool-size=512M"
  - "--max-connections=200"
```

#### Log Management

**Rotation Configuration:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### Disaster Recovery

#### Recovery Plan

**Critical Service Recovery Order:**
1. Traefik (networking)
2. Authelia (authentication)
3. Databases (dependencies)
4. Core services (Home Assistant, Nextcloud)
5. Supporting services
6. Monitoring services

#### Testing Recovery

**Quarterly DR Test:**
```bash
# 1. Stop all services
docker-compose down

# 2. Restore from backup
tar -xzf backups/latest-backup.tar.gz

# 3. Restore databases
# (See BACKUP.md for specific commands)

# 4. Restart services
docker-compose up -d

# 5. Verify all services functional
./scripts/health-check.sh
```

### Maintenance Schedule

#### Daily
- Automated backups (via cron)
- Log review (automated via monitoring)

#### Weekly
- Review Uptime Kuma for service disruptions
- Check for security updates
- Review resource usage trends in Grafana

#### Monthly
- Update containers (after testing)
- Review and rotate logs
- Test backup restoration
- Review and update documentation
- Audit user access and permissions

#### Quarterly
- Full disaster recovery test
- Security audit
- Review and update SSL certificates
- Capacity planning review

### Common Pitfalls to Avoid

**❌ Don't:**
- Use `:latest` tags in production
- Skip backups before updates
- Run all services as root
- Expose services directly to internet without authentication
- Ignore security updates
- Store secrets in docker-compose.yml
- Commit `.env` file to git
- Disable health checks
- Ignore resource limits

**✅ Do:**
- Pin specific versions
- Always backup before changes
- Use non-root users (PUID/PGID)
- Use reverse proxy with authentication
- Subscribe to security advisories
- Use environment variables for secrets
- Keep `.env` in `.gitignore`
- Implement comprehensive health checks
- Set appropriate resource limits

### Compliance & Privacy

**GDPR Considerations:**
- Document data retention policies
- Implement data export capabilities
- Provide user data deletion mechanisms
- Encrypt backups containing personal data

**Logging Best Practices:**
- Don't log sensitive information (passwords, tokens)
- Implement log retention policies
- Secure log storage and access
- Consider legal requirements for log retention

### Optimization Tips

**Reduce Resource Usage:**
```bash
# Prune unused resources weekly
docker system prune -af --volumes --filter "until=168h"

# Monitor and optimize largest consumers
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Network Performance:**
- Use host networking sparingly (security vs performance)
- Enable compression in Traefik
- Implement caching where appropriate

**Database Performance:**
- Regular VACUUM on PostgreSQL
- Optimize MariaDB tables monthly
- Monitor slow queries
- Index optimization

### Documentation

**Keep Updated:**
- Configuration changes
- Custom modifications
- Network topology
- Access credentials (in secure location)
- Disaster recovery procedures
- Contact information for support

**Document Format:**
```
docs/
├── SETUP.md (initial setup)
├── ARCHITECTURE.md (system design)
├── RUNBOOK.md (operational procedures)
├── TROUBLESHOOTING.md (common issues)
└── CHANGELOG.md (changes over time)
```

---

**Remember:** Security and reliability require ongoing effort. Regular maintenance, monitoring, and updates are essential for a production-ready system.
