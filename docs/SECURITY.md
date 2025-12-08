# Security Hardening Guide

## 🔒 Comprehensive Security Configuration

### Initial Security Setup

#### 1. Synology DSM Hardening

**Update DSM:**
```bash
# Always run latest stable DSM version
# Control Panel → Update & Restore → DSM Update
```

**Enable Security Features:**
- ✅ Enable auto-block for failed login attempts
- ✅ Enable firewall (allow only necessary ports)
- ✅ Disable unused services (FTP, Telnet, etc.)
- ✅ Enable account protection
- ✅ Set up 2FA for DSM admin account
- ✅ Enable notifications for security events

**Firewall Configuration:**
```
Allow from All Sources:
- Port 80/TCP (HTTP - will redirect to HTTPS)
- Port 443/TCP (HTTPS)
- Port 51820/UDP (WireGuard VPN)

Allow from Local Network Only:
- Port 22/TCP (SSH)
- Port 5000/TCP (DSM HTTP)
- Port 5001/TCP (DSM HTTPS)
- Port 9000/TCP (Portainer)

Block all other incoming traffic
```

**SSH Hardening:**
```bash
# Edit SSH config
sudo vi /etc/ssh/sshd_config

# Recommended settings:
PermitRootLogin no
PasswordAuthentication no  # Use SSH keys only
PubkeyAuthentication yes
Port 22222  # Change default port
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers yourusername  # Limit to specific users

# Restart SSH
sudo synoservicectl --reload sshd
```

#### 2. Docker Security

**Docker Daemon Configuration:**
```bash
# On Synology, edit /var/packages/Docker/etc/dockerd.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}

# Restart Docker
sudo synoservicectl --restart pkgctl-Docker
```

**User Namespaces:**
```bash
# Enable user namespace remapping for additional isolation
# This maps container root to non-privileged host user
```

### Service-Specific Security

#### Traefik Reverse Proxy

**Security Headers (already configured):**
```yaml
headers:
  frameDeny: true
  browserXssFilter: true
  contentTypeNosniff: true
  forceSTSHeader: true
  stsSeconds: 31536000
  stsIncludeSubdomains: true
  stsPreload: true
```

**Additional Hardening:**
```yaml
# Add to dynamic/middlewares.yml
http:
  middlewares:
    # Restrict access to specific countries (example)
    geoblock:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"  # Localhost
          - "192.168.1.0/24"  # Local network
          # Add your country's IP ranges if needed

    # Advanced rate limiting
    rate-limit-aggressive:
      rateLimit:
        average: 10
        burst: 5
        period: 1m
        sourceCriterion:
          ipStrategy:
            depth: 1
```

**Disable Dashboard in Production:**
```yaml
# In traefik.yml
api:
  dashboard: false  # Set to false after initial setup
  insecure: false
```

#### Authelia 2FA

**Strong Password Hashing:**
```yaml
# Already configured with Argon2id
password:
  algorithm: argon2id
  iterations: 3
  key_length: 32
  salt_length: 16
  memory: 65536  # 64MB
  parallelism: 4
```

**Session Security:**
```yaml
session:
  secret: USE_ENV_VARIABLE
  expiration: 1h  # Short session timeout
  inactivity: 5m  # Auto-logout after inactivity
  remember_me_duration: 1M
  cookies:
    - domain: yourdomain.com
      authelia_url: https://auth.yourdomain.com
      default_redirection_url: https://yourdomain.com
      secure: true  # HTTPS only
      same_site: lax
```

**Access Control Rules:**
```yaml
access_control:
  default_policy: deny  # Deny by default

  rules:
    # Public access to auth portal
    - domain: 'auth.yourdomain.com'
      policy: bypass

    # Bypass for monitoring (internal network only)
    - domain: 'status.yourdomain.com'
      policy: bypass
      networks:
        - '192.168.1.0/24'

    # Admin services require 2FA
    - domain:
        - 'portainer.yourdomain.com'
        - 'grafana.yourdomain.com'
      policy: two_factor
      subject:
        - 'group:admins'

    # All other services require 2FA
    - domain: '*.yourdomain.com'
      policy: two_factor
```

**Failed Authentication Protection:**
```yaml
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 10m  # Increase from default
```

#### Vaultwarden Password Manager

**Disable Registration:**
```yaml
environment:
  - SIGNUPS_ALLOWED=false  # Critical!
  - SIGNUPS_VERIFY=true
  - INVITATIONS_ALLOWED=true  # Control user creation
  - ADMIN_TOKEN=${STRONG_RANDOM_TOKEN}
```

**Additional Security:**
```yaml
environment:
  - DOMAIN=https://vault.${DOMAIN}
  - LOG_LEVEL=warn
  - EXTENDED_LOGGING=true
  - LOG_FILE=/data/vaultwarden.log
  - WEBSOCKET_ENABLED=true
  - WEB_VAULT_ENABLED=true
  - DISABLE_ICON_DOWNLOAD=false
  - IP_HEADER=X-Forwarded-For
  - ADMIN_RATELIMIT_SECONDS=300
  - ADMIN_RATELIMIT_MAX_BURST=3
```

#### WireGuard VPN

**Secure Configuration:**
```ini
# config/wireguard/wg0.conf
[Interface]
Address = 10.13.13.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configurations
[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.13.13.2/32
PersistentKeepalive = 25
```

**Firewall Rules:**
```bash
# Only allow WireGuard VPN port from internet
# All other access should be through VPN tunnel
```

#### Database Security

**PostgreSQL (Immich, Paperless):**
```yaml
environment:
  - POSTGRES_PASSWORD=${STRONG_PASSWORD}
  - POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256

command:
  - "postgres"
  - "-c"
  - "ssl=off"  # Internal network, SSL via Traefik
  - "-c"
  - "log_connections=on"
  - "-c"
  - "log_disconnections=on"
  - "-c"
  - "log_duration=on"
```

**MariaDB (Nextcloud):**
```yaml
environment:
  - MYSQL_ROOT_PASSWORD=${STRONG_PASSWORD}
  - MYSQL_PASSWORD=${STRONG_PASSWORD}

command:
  - "--skip-name-resolve"  # Prevent DNS lookups
  - "--skip-networking=false"
  - "--bind-address=0.0.0.0"
```

#### Nextcloud Security

**Trusted Domains & Proxies:**
```php
// config/config.php (auto-generated, but verify)
'trusted_domains' => [
  'cloud.yourdomain.com',
  '192.168.1.100',
],
'trusted_proxies' => ['172.20.0.0/16'],
'overwriteprotocol' => 'https',
'overwritehost' => 'cloud.yourdomain.com',
```

**Additional Security Settings:**
```bash
# Execute in Nextcloud container
docker exec -u www-data nextcloud php occ config:system:set auth.bruteforce.protection.enabled --value true --type boolean
docker exec -u www-data nextcloud php occ config:system:set loglevel --value 2
docker exec -u www-data nextcloud php occ config:system:set log_type --value file
docker exec -u www-data nextcloud php occ security:bruteforce:reset YOUR_IP
```

### Network Security

#### Docker Network Isolation

**Network Segmentation:**
```yaml
networks:
  proxy:        # Public-facing services via Traefik
  storage:      # Database and storage services (isolated)
  monitoring:   # Monitoring stack (isolated)
  homeautomation: # HA and MQTT (isolated)
  internal:     # Completely internal (no external access)
    internal: true
```

**Prevent Container-to-Container Attacks:**
```yaml
# Default deny, explicit allow
networks:
  storage:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

#### Port Exposure Minimization

**Only Expose Necessary Ports:**
```yaml
# Good - expose to Docker network only
expose:
  - 8080

# Careful - expose to host
ports:
  - "127.0.0.1:8080:8080"  # Localhost only

# Avoid - expose to world
ports:
  - "8080:8080"  # All interfaces
```

### Secret Management

#### Environment Variables Security

**Never Commit Secrets:**
```bash
# .gitignore
.env
*.env
!.env.example
config/**/secrets.yml
*.key
*.pem
```

**Use Strong Secrets:**
```bash
# Generate strong passwords
openssl rand -hex 32          # 64-character hex
openssl rand -base64 48       # 64-character base64
pwgen -s 32 1                 # 32-character alphanumeric

# Generate for Authelia users
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR_PASSWORD'
```

**Rotate Secrets Regularly:**
```bash
# Quarterly rotation schedule:
# 1. Generate new secrets
# 2. Update .env file
# 3. Restart affected services
# 4. Verify functionality
# 5. Revoke old secrets
```

#### Secure File Permissions

```bash
# Restrict access to sensitive files
chmod 600 .env
chmod 600 config/traefik/acme/acme.json
chmod 600 config/authelia/users_database.yml
chmod 700 scripts/*.sh

# Ensure proper ownership
chown -R 1000:1000 config/
chown -R 1000:1000 data/
```

### Monitoring & Intrusion Detection

#### Log Monitoring

**Centralized Logging:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
    labels: "service,environment"
```

**Important Events to Monitor:**
- Failed login attempts (Authelia, Nextcloud, etc.)
- Unusual traffic patterns (Traefik access logs)
- Container restarts (Docker events)
- Resource exhaustion (Prometheus alerts)
- Certificate issues (Traefik logs)

#### Prometheus Alerts

**Create Alert Rules:**
```yaml
# config/prometheus/alerts/security.yml
groups:
  - name: security_alerts
    interval: 30s
    rules:
      - alert: HighAuthFailureRate
        expr: rate(authelia_authentication_failed_total[5m]) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High authentication failure rate"

      - alert: ContainerDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.instance }} is down"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} using >90% memory"
```

#### Fail2Ban Integration (Optional)

**Install on Synology:**
```bash
# Monitor Traefik access logs for attack patterns
# Ban IPs with excessive failed attempts

[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /volume1/docker/synology-stack/logs/traefik/access.log
maxretry = 5
findtime = 600
bantime = 86400
```

### Compliance & Audit

#### Security Audit Checklist

**Monthly Security Review:**
- [ ] Review all user accounts and access levels
- [ ] Check for unauthorized containers or services
- [ ] Verify SSL certificates are valid and not expiring
- [ ] Review authentication logs for suspicious activity
- [ ] Check for container and image updates
- [ ] Verify backup integrity and test restore
- [ ] Review firewall rules
- [ ] Scan for vulnerable containers (see below)

**Container Vulnerability Scanning:**
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

#### Compliance Requirements

**GDPR Considerations:**
```yaml
# Document in your privacy policy:
1. What data is collected (logs, user files, etc.)
2. Where data is stored (NAS location, backups)
3. Data retention periods
4. Data protection measures (encryption, access control)
5. User rights (access, deletion, portability)
```

**Data Protection:**
```bash
# Encrypt sensitive backups
tar -czf - backups/ | openssl enc -aes-256-cbc -salt -out backups-encrypted.tar.gz.enc

# Decrypt when needed
openssl enc -d -aes-256-cbc -in backups-encrypted.tar.gz.enc | tar -xzf -
```

### Incident Response

#### Security Incident Procedure

**1. Detection:**
- Monitor Uptime Kuma for service disruptions
- Review Grafana dashboards for anomalies
- Check Authelia logs for brute force attempts
- Review Traefik access logs for suspicious patterns

**2. Containment:**
```bash
# Immediately isolate affected container
docker network disconnect proxy compromised-container

# Stop the container if necessary
docker stop compromised-container

# Block attacking IPs at firewall level
```

**3. Investigation:**
```bash
# Examine container logs
docker logs compromised-container > incident-logs.txt

# Check for file modifications
docker diff compromised-container

# Export container for forensics
docker export compromised-container > container-forensics.tar
```

**4. Recovery:**
```bash
# Restore from clean backup
./scripts/restore.sh service-name

# Rotate all secrets
# Update .env with new passwords
docker-compose up -d

# Verify integrity
./scripts/health-check.sh
```

**5. Post-Incident:**
- Document what happened
- Update security measures to prevent recurrence
- Review and update incident response procedures

### Additional Security Measures

#### Regular Security Tasks

**Daily (Automated):**
```bash
# Automated backup
0 2 * * * /volume1/docker/synology-stack/scripts/backup.sh

# Log review (automated via monitoring)
```

**Weekly:**
```bash
# Check for security updates
docker-compose pull

# Review authentication logs
grep "Failed" logs/traefik/access.log | tail -100

# Verify all services running
./scripts/health-check.sh
```

**Monthly:**
```bash
# Security scan
./trivy image $(docker images --format "{{.Repository}}:{{.Tag}}")

# Access audit
# Review user accounts in Authelia, Nextcloud, etc.

# Certificate check
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

**Quarterly:**
```bash
# Penetration testing (if feasible)
# Password rotation
# Review and update firewall rules
# Disaster recovery test
```

#### Security Resources

**Stay Informed:**
- Subscribe to security advisories for all used software
- Follow Docker security best practices
- Monitor CVE databases for vulnerabilities
- Join Synology community forums

**Tools:**
- [Trivy](https://github.com/aquasecurity/trivy) - Container vulnerability scanning
- [Docker Bench Security](https://github.com/docker/docker-bench-security) - Docker security audit
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) - Web application security

---

**Remember:** Security is an ongoing process, not a one-time setup. Regular monitoring, updates, and audits are essential.

---

---

[Back to Main README](../README.md) | [Best Practices](BEST_PRACTICES.md) | [Troubleshooting](TROUBLESHOOTING.md)
