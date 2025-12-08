# Comprehensive Setup Guide

## 📋 Prerequisites

### Hardware Requirements
- Synology DS 224+ (or compatible model)
- 16GB RAM installed
- Minimum 50GB free space for containers
- Additional storage for data (Nextcloud, Immich, Paperless)
- Stable internet connection
- UPS recommended for power protection

### Software Requirements
- DSM 7.x or later
- Docker package installed
- SSH access enabled
- Static IP configured on NAS
- Domain name (for external access)
- CloudFlare account (or alternative DNS provider)

### Knowledge Requirements
- Basic Linux command line
- Docker and docker-compose fundamentals
- Networking basics (ports, DNS, reverse proxy concepts)
- Basic understanding of your domain DNS settings

## 🔧 Pre-Installation Setup

### Step 1: Prepare Synology NAS

#### Update DSM
1. Log into DSM
2. Go to **Control Panel** → **Update & Restore**
3. Install latest DSM updates
4. Reboot if required

#### Install Docker
1. Open **Package Center**
2. Search for "Docker"
3. Click **Install**
4. Wait for installation to complete

#### Enable SSH
1. Go to **Control Panel** → **Terminal & SNMP**
2. Enable SSH service
3. Change default port (recommended: 22222)
4. Click **Apply**

#### Configure Firewall
1. Go to **Control Panel** → **Security** → **Firewall**
2. Create firewall profile:
   ```
   Allow:
   - 80/TCP (HTTP)
   - 443/TCP (HTTPS)
   - 51820/UDP (WireGuard)
   - 22222/TCP (SSH - from trusted IPs only)

   Deny: All other ports
   ```

#### Set Static IP
1. Go to **Control Panel** → **Network** → **Network Interface**
2. Edit LAN interface
3. Set manual IP configuration:
   ```
   IP: 192.168.1.100 (example - use your network)
   Subnet: 255.255.255.0
   Gateway: 192.168.1.1 (your router)
   DNS: 1.1.1.1, 8.8.8.8
   ```

### Step 2: DNS and Domain Setup

#### Register Domain
- Purchase domain from registrar (Namecheap, Google Domains, etc.)
- Or use free dynamic DNS (DuckDNS, No-IP)

#### Configure CloudFlare
1. Create CloudFlare account at cloudflare.com
2. Add your domain
3. Update nameservers at your registrar to CloudFlare's
4. Wait for DNS propagation (up to 48 hours)

#### Create DNS Records
In CloudFlare DNS settings, add:
```
Type: A
Name: @
Content: YOUR_PUBLIC_IP
Proxy: Off (orange cloud disabled)
TTL: Auto

Type: CNAME
Name: *
Content: yourdomain.com
Proxy: Off
TTL: Auto
```

#### Get CloudFlare API Token
1. Go to **My Profile** → **API Tokens**
2. Click **Create Token**
3. Use "Edit zone DNS" template
4. Zone Resources: Include → Specific zone → yourdomain.com
5. Click **Continue to summary** → **Create Token**
6. **Save this token securely!**

### Step 3: Prepare Storage

#### Create Volume Directories
SSH into your NAS and create storage directories:

```bash
# Main data directories
sudo mkdir -p /volume1/nextcloud-data
sudo mkdir -p /volume1/immich-library
sudo mkdir -p /volume1/paperless/{consume,export}

# Set permissions
sudo chown -R 1000:1000 /volume1/nextcloud-data
sudo chown -R 1000:1000 /volume1/immich-library
sudo chown -R 1000:1000 /volume1/paperless
```

## 🚀 Installation

### Step 1: Clone Repository

```bash
# SSH into your NAS
ssh admin@192.168.1.100 -p 22222

# Navigate to Docker directory
cd /volume1/docker

# Clone repository
git clone https://github.com/yourusername/synology-stack.git
cd synology-stack
```

### Step 2: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

#### Required Configuration Values

**Global Settings:**
```bash
TZ=America/New_York  # Your timezone
DOMAIN=yourdomain.com
NAS_IP=192.168.1.100
```

**CloudFlare:**
```bash
CF_API_EMAIL=your-email@example.com
CF_DNS_API_TOKEN=your-api-token-from-cloudflare
```

**Generate Secrets:**
```bash
# Authelia secrets (run these commands)
openssl rand -hex 32  # Copy for AUTHELIA_JWT_SECRET
openssl rand -hex 32  # Copy for AUTHELIA_SESSION_SECRET
openssl rand -hex 32  # Copy for AUTHELIA_STORAGE_ENCRYPTION_KEY

# Vaultwarden admin token
openssl rand -base64 48  # Copy for VAULTWARDEN_ADMIN_TOKEN

# Paperless secret
openssl rand -base64 32  # Copy for PAPERLESS_SECRET_KEY
```

**Service Passwords:**
```bash
# Generate strong passwords for each service
openssl rand -base64 32

# Set these in .env:
NEXTCLOUD_ADMIN_PASSWORD=
NEXTCLOUD_DB_PASSWORD=
NEXTCLOUD_DB_ROOT_PASSWORD=
IMMICH_DB_PASSWORD=
PAPERLESS_DB_PASSWORD=
PAPERLESS_ADMIN_PASSWORD=
GRAFANA_ADMIN_PASSWORD=
```

**SMTP (Optional but Recommended):**
```bash
# For Gmail, create app-specific password at:
# https://myaccount.google.com/apppasswords

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_FROM=noreply@yourdomain.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

**Storage Paths:**
```bash
NEXTCLOUD_DATA_PATH=/volume1/nextcloud-data
IMMICH_UPLOAD_LOCATION=/volume1/immich-library
PAPERLESS_CONSUME_DIR=/volume1/paperless/consume
PAPERLESS_EXPORT_DIR=/volume1/paperless/export
```

**WireGuard:**
```bash
WIREGUARD_SERVERURL=vpn.yourdomain.com  # Or your public IP
WIREGUARD_PEERS=laptop,phone,tablet  # Device names
```

### Step 3: Update Configuration Files

#### Traefik Configuration
```bash
nano config/traefik/traefik.yml
```

Update:
- Line 53: Change `email: your-email@example.com` to your email
- Line 58: Change domains to match your domain

#### Authelia Configuration
```bash
nano config/authelia/configuration.yml
```

Update all instances of `yourdomain.com` to your actual domain.

#### Authelia Users
```bash
# Generate password hash for your admin user
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourStrongPassword'

# Edit users file
nano config/authelia/users_database.yml
```

Replace the example password hash with your generated hash.

### Step 4: Create Directory Structure

```bash
# Run setup script
chmod +x scripts/setup-directories.sh
./scripts/setup-directories.sh
```

### Step 5: Create Mosquitto Password

```bash
# Create MQTT user for Home Assistant
docker run -it --rm -v $(pwd)/config/mosquitto:/mosquitto/config eclipse-mosquitto:2.0.18 mosquitto_passwd -c /mosquitto/config/passwd mqttuser

# Enter password when prompted (save this for Home Assistant config)
```

### Step 6: Validate Configuration

```bash
# Check docker-compose syntax
docker-compose config

# Should output the full configuration without errors
```

## 🎯 Deployment

### Step 1: Start Core Services

```bash
# Start Traefik first
docker-compose up -d traefik

# Wait 30 seconds for certificates
sleep 30

# Check Traefik logs
docker-compose logs traefik

# Look for "Server responded with a certificate"
```

### Step 2: Start Authentication

```bash
# Start Authelia
docker-compose up -d authelia

# Check logs
docker-compose logs -f authelia

# Look for "Authelia is listening"
```

### Step 3: Start All Services

```bash
# Start everything
docker-compose up -d

# Monitor startup
docker-compose logs -f
```

### Step 4: Verify Services

```bash
# Check all containers are running
docker-compose ps

# All should show "Up" status

# Run health check
./scripts/health-check.sh
```

## 🔐 Post-Installation Configuration

### 1. Access Portainer

Navigate to: `http://YOUR_NAS_IP:9000`

1. Create admin account (do this within 5 minutes!)
2. Select "Local" environment
3. Connect to local Docker
4. Explore container dashboard

### 2. Configure Authelia 2FA

Navigate to: `https://auth.yourdomain.com`

1. Login with credentials from `users_database.yml`
2. Setup 2FA (TOTP app like Google Authenticator)
3. Scan QR code
4. Enter code to verify
5. Save backup codes securely

### 3. Setup Vaultwarden

Navigate to: `https://vault.yourdomain.com`

1. Access admin panel: `https://vault.yourdomain.com/admin`
2. Enter admin token from `.env`
3. Configure SMTP in admin panel (optional)
4. Create your first user account
5. Install browser extension
6. Install mobile app

### 4. Configure Home Assistant

Navigate to: `https://ha.yourdomain.com`

1. Create account (first user is admin)
2. Set location and timezone
3. Configure MQTT broker:
   ```yaml
   # configuration.yaml
   mqtt:
     broker: mosquitto
     port: 1883
     username: mqttuser
     password: your-mqtt-password
   ```
4. Add integrations as needed

### 5. Setup Node-RED

Navigate to: `https://nodered.yourdomain.com`

1. Login via Authelia
2. Install additional nodes if needed:
   - node-red-contrib-home-assistant-websocket
   - node-red-dashboard
3. Configure Home Assistant connection

### 6. Configure Nextcloud

Navigate to: `https://cloud.yourdomain.com`

1. Login with credentials from `.env`
2. Install recommended apps
3. Configure background jobs:
   ```bash
   docker exec -u www-data nextcloud php occ background:cron
   ```
4. Add cron job in DSM Task Scheduler:
   ```bash
   docker exec -u www-data nextcloud php -f /var/www/html/cron.php
   ```
   Schedule: Every 5 minutes

### 7. Setup Immich

Navigate to: `https://photos.yourdomain.com`

1. Create admin account
2. Upload photos via web or mobile app
3. Install mobile apps (iOS/Android)
4. Configure machine learning (optional)

### 8. Configure Paperless-ngx

Navigate to: `https://docs.yourdomain.com`

1. Login with credentials from `.env`
2. Configure consumption folder scanning
3. Set up OCR languages if needed
4. Create tags and correspondents

### 9. Setup Monitoring

#### Grafana
Navigate to: `https://grafana.yourdomain.com`

1. Login via Authelia
2. Prometheus datasource should be auto-configured
3. Import dashboards:
   - Dashboard ID 1860 (Node Exporter)
   - Dashboard ID 893 (Docker)
   - Dashboard ID 12705 (Traefik)

#### Uptime Kuma
Navigate to: `https://status.yourdomain.com`

1. Create account
2. Add monitors for each service:
   ```
   Type: HTTP(s)
   URL: https://service.yourdomain.com
   Interval: 60 seconds
   ```

### 10. Setup WireGuard VPN

```bash
# Get client configurations
docker exec wireguard cat /config/peer_laptop/peer_laptop.conf

# Or download from
/volume1/docker/synology-stack/config/wireguard/peer_laptop/
```

Import configuration in WireGuard client:
- Desktop: WireGuard app
- iOS: WireGuard app from App Store
- Android: WireGuard app from Play Store

## ✅ Validation Checklist

After setup, verify:

- [ ] All 15 containers running (`docker-compose ps`)
- [ ] SSL certificates issued (check Traefik logs)
- [ ] Authelia 2FA working
- [ ] Can access all services via HTTPS
- [ ] Monitoring dashboards populated with data
- [ ] Backups script runs successfully
- [ ] WireGuard VPN connects
- [ ] Email notifications working (if configured)
- [ ] Home Assistant sees MQTT broker
- [ ] Nextcloud mobile sync working
- [ ] No errors in container logs

## 🎓 Next Steps

1. **Review Security Guide:** Read `docs/SECURITY.md` and implement hardening
2. **Setup Backups:** Configure automated backups (see `docs/BACKUP.md`)
3. **Configure Monitoring:** Set up alerts in Grafana/Uptime Kuma
4. **Customize Services:** Configure each service for your needs
5. **Test Disaster Recovery:** Verify backup restore procedures

## ⚠️ Common Issues

### Traefik Certificate Issues
```bash
# Check logs
docker-compose logs traefik | grep -i error

# Verify DNS is pointing to your IP
nslookup yourdomain.com

# Ensure ports 80/443 are forwarded to NAS
```

### Container Won't Start
```bash
# Check specific container logs
docker-compose logs servicename

# Verify .env file is complete
cat .env

# Check permissions
ls -la config/ data/
```

### Can't Access Services
```bash
# Verify Traefik is running
docker-compose ps traefik

# Check Traefik dashboard
http://YOUR_NAS_IP:8080

# Verify DNS resolves correctly
nslookup service.yourdomain.com
```

For more troubleshooting, see `docs/TROUBLESHOOTING.md`

## 📞 Support

- Check documentation in `docs/` folder
- Review service logs: `docker-compose logs servicename`
- Search GitHub issues
- Consult service-specific documentation

---

**Congratulations!** Your Synology container stack is now configured and ready for production use.

---

[Back to Main README](../README.md) | [Security Guide](SECURITY.md) | [Best Practices](BEST_PRACTICES.md) | [Troubleshooting](TROUBLESHOOTING.md)
