# Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### Docker Not Running
**Symptom:** `Cannot connect to the Docker daemon`

**Solution:**
```bash
# Check Docker status
sudo synoservicectl --status pkgctl-Docker

# Restart Docker
sudo synoservicectl --restart pkgctl-Docker

# Wait 30 seconds, then try again
docker ps
```

#### Permission Denied
**Symptom:** `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Add your user to docker group
sudo synogroup --add docker $USER

# Logout and login again for changes to take effect
exit
```

#### Directory Creation Fails
**Symptom:** `mkdir: cannot create directory: Permission denied`

**Solution:**
```bash
# Run setup script with sudo
sudo ./scripts/setup-directories.sh

# Or manually fix permissions
sudo chown -R $(whoami):$(whoami) /volume1/docker/synology-stack
```

### SSL/Certificate Issues

#### Traefik Can't Get Certificates
**Symptom:** `unable to obtain ACME certificate`

**Solution:**
1. Verify DNS is pointing to your public IP:
   ```bash
   nslookup yourdomain.com
   ```

2. Check CloudFlare API credentials in `.env`:
   ```bash
   grep CF_ .env
   ```

3. Ensure ports 80/443 are forwarded to NAS

4. Check Traefik logs:
   ```bash
   docker-compose logs traefik | grep -i error
   ```

5. Verify CloudFlare API token has correct permissions:
   - Zone:DNS:Edit
   - Zone:Zone:Read

6. Reset acme.json:
   ```bash
   docker-compose down traefik
   rm config/traefik/acme/acme.json
   touch config/traefik/acme/acme.json
   chmod 600 config/traefik/acme/acme.json
   docker-compose up -d traefik
   ```

#### SSL Certificate Expired
**Symptom:** Browser shows certificate error

**Solution:**
```bash
# Traefik auto-renews, but you can force renewal:
docker-compose restart traefik

# Check certificate validity
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com | openssl x509 -noout -dates
```

### Service Won't Start

#### Container Keeps Restarting
**Symptom:** `docker-compose ps` shows container restarting

**Solution:**
```bash
# Check logs for the specific service
docker-compose logs servicename

# Common issues:
# 1. Port already in use
sudo netstat -tulpn | grep PORT_NUMBER

# 2. Permission issues
sudo chown -R 1000:1000 config/servicename data/servicename

# 3. Configuration error
docker-compose config | grep servicename

# 4. Resource limits too low
# Edit docker-compose.yml to increase mem_limit
```

#### Database Connection Failed
**Symptom:** Service can't connect to its database

**Solution:**
```bash
# Verify database container is running
docker-compose ps | grep db

# Check database logs
docker-compose logs nextcloud-db
docker-compose logs immich-postgres
docker-compose logs paperless-db

# Verify password in .env matches
grep DB_PASSWORD .env

# Restart both service and database
docker-compose restart servicename servicename-db
```

### Network Issues

#### Can't Access Services Externally
**Symptom:** Services work locally but not from internet

**Solution:**
1. Verify port forwarding on router:
   - Port 80 → NAS_IP:80
   - Port 443 → NAS_IP:443
   - Port 51820 (UDP) → NAS_IP:51820

2. Check firewall rules:
   - DSM → Control Panel → Security → Firewall
   - Ensure rules allow 80, 443, 51820

3. Verify Traefik is receiving requests:
   ```bash
   tail -f logs/traefik/access.log
   ```

4. Test DNS resolution:
   ```bash
   nslookup service.yourdomain.com
   dig service.yourdomain.com
   ```

#### Services Timeout or Very Slow
**Symptom:** Long loading times or timeouts

**Solution:**
```bash
# Check resource usage
docker stats

# Check for memory pressure
free -h

# Check disk I/O
iostat -x 1

# Restart overloaded containers
docker-compose restart servicename

# Consider upgrading RAM or optimizing services
```

### Authentication Issues

#### Authelia Won't Accept Login
**Symptom:** Incorrect username or password

**Solution:**
```bash
# Verify user exists in users_database.yml
cat config/authelia/users_database.yml

# Reset password hash:
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'NewPassword'

# Update users_database.yml with new hash
nano config/authelia/users_database.yml

# Restart Authelia
docker-compose restart authelia
```

#### 2FA Code Not Working
**Symptom:** TOTP code rejected

**Solution:**
1. Check time synchronization:
   ```bash
   # On NAS
   date
   # Should match real time within 30 seconds
   ```

2. Sync NAS time:
   - DSM → Control Panel → Regional Options → Time
   - Enable NTP
   - Sync now

3. Use backup codes if available

4. Reset 2FA (last resort):
   - Edit `config/authelia/users_database.yml`
   - Remove TOTP secret for user
   - Restart Authelia
   - Login and setup 2FA again

#### Locked Out After Failed Attempts
**Symptom:** "User is banned"

**Solution:**
```bash
# Wait for ban time (default 10 minutes)
# Or reset regulation:
docker-compose restart authelia

# Or remove ban from database (SQLite):
docker exec -it authelia sqlite3 /config/db.sqlite3 "DELETE FROM regulation;"
```

### Service-Specific Issues

#### Nextcloud: Can't Login
**Symptom:** Invalid username or password

**Solution:**
```bash
# Reset admin password
docker exec -u www-data nextcloud php occ user:resetpassword admin

# Or create new admin user
docker exec -u www-data nextcloud php occ user:add newadmin --group admin
```

#### Home Assistant: MQTT Not Connected
**Symptom:** MQTT integration offline

**Solution:**
```bash
# Verify Mosquitto is running
docker-compose ps mosquitto

# Check Mosquitto logs
docker-compose logs mosquitto

# Verify credentials
docker exec mosquitto cat /mosquitto/config/passwd

# Recreate password file
docker run -it --rm -v $(pwd)/config/mosquitto:/mosquitto/config eclipse-mosquitto:latest mosquitto_passwd -c /mosquitto/config/passwd mqttuser

# Restart Mosquitto
docker-compose restart mosquitto
```

#### Immich: Upload Fails
**Symptom:** Can't upload photos

**Solution:**
```bash
# Check permissions on upload directory
ls -la /volume1/immich-library

# Fix permissions
sudo chown -R 1000:1000 /volume1/immich-library
sudo chmod -R 755 /volume1/immich-library

# Check disk space
df -h

# Restart Immich
docker-compose restart immich-server
```

#### Paperless: Documents Not Processing
**Symptom:** Documents stuck in consume folder

**Solution:**
```bash
# Check Paperless logs
docker-compose logs paperless-ngx | grep -i error

# Verify consume directory permissions
ls -la /volume1/paperless/consume

# Fix permissions
sudo chown -R 1000:1000 /volume1/paperless

# Restart Paperless
docker-compose restart paperless-ngx

# Trigger manual consumption
docker exec paperless-ngx document_consumer
```

### Performance Issues

#### High Memory Usage
**Symptom:** System slow, containers being killed

**Solution:**
```bash
# Check memory usage
docker stats --no-stream

# Identify memory hogs
docker stats --format "table {{.Name}}\t{{.MemUsage}}" | sort -k 2 -h

# Reduce memory limits if needed (edit docker-compose.yml)

# Restart high-memory services
docker-compose restart servicename

# Clear Docker cache
docker system prune -a
```

#### High CPU Usage
**Symptom:** System very slow, high load average

**Solution:**
```bash
# Check CPU usage per container
docker stats --format "table {{.Name}}\t{{.CPUPerc}}"

# Check for runaway processes
top

# Restart problematic service
docker-compose restart servicename

# Check for scanning/indexing operations
# (Nextcloud, Paperless, Immich may scan files)
```

#### Disk Full
**Symptom:** `no space left on device`

**Solution:**
```bash
# Check disk usage
df -h

# Find large directories
du -h --max-depth=1 /volume1/docker | sort -h

# Clean Docker system
docker system prune -af --volumes

# Clean old logs
find logs/ -name "*.log" -mtime +30 -delete

# Clean old backups
find backups/ -name "*.tar.gz" -mtime +30 -delete

# Check specific service data
du -sh data/*
```

### Backup & Restore Issues

#### Backup Script Fails
**Symptom:** Backup incomplete or errors

**Solution:**
```bash
# Run backup manually to see errors
./scripts/backup.sh

# Check disk space for backups
df -h /volume1/docker/backups

# Verify script permissions
chmod +x scripts/backup.sh

# Check individual service accessibility
docker exec servicename ls /
```

#### Restore Fails
**Symptom:** Can't restore from backup

**Solution:**
```bash
# Ensure containers are stopped
docker-compose down

# Extract backup
tar -xzf backups/backup-file.tar.gz

# Restore configs
cp -r backup/config/* config/

# Restore databases manually
docker-compose up -d servicename-db
# Wait for DB to start
docker exec -i servicename-db mysql -u user -ppassword database < backup.sql

# Start all services
docker-compose up -d
```

### Update Issues

#### Update Breaks Service
**Symptom:** Service won't start after update

**Solution:**
```bash
# Roll back to previous version
docker-compose down servicename

# Edit docker-compose.yml to use previous version
# Change: image: service:new-version
# To: image: service:old-version

docker-compose up -d servicename

# Check release notes for breaking changes
# Consult service documentation
```

## Diagnostic Commands

### Check Everything
```bash
# Run health check
./scripts/health-check.sh

# Check all container logs
docker-compose logs --tail=50

# Check resource usage
docker stats --no-stream

# Verify configuration
docker-compose config

# Check network connectivity
docker network ls
docker network inspect proxy
```

### Log Analysis
```bash
# View logs for specific service
docker-compose logs servicename

# Follow logs in real-time
docker-compose logs -f servicename

# Last 100 lines
docker-compose logs --tail=100 servicename

# Search logs for errors
docker-compose logs | grep -i error

# Check logs from specific time
docker-compose logs --since 30m servicename
```

### Container Inspection
```bash
# Detailed container info
docker inspect containername

# Check container health
docker inspect containername | grep -A 10 Health

# View container processes
docker top containername

# Execute commands in container
docker exec -it containername /bin/sh
```

## Getting Help

If you can't resolve the issue:

1. **Check Documentation:**
   - Service-specific docs in `docs/`
   - Official documentation for each service

2. **Review Logs:**
   - Container logs: `docker-compose logs servicename`
   - System logs: `/var/log/` on NAS

3. **Search Issues:**
   - GitHub repository issues
   - Service-specific GitHub issues
   - Synology community forums

4. **Ask for Help:**
   - Include error messages
   - Include relevant logs
   - Describe what you've tried
   - Include your setup details (DSM version, RAM, etc.)

## Prevention

### Regular Maintenance
- Run health checks weekly
- Review logs for errors
- Monitor disk space
- Test backups monthly
- Keep services updated
- Document any changes

### Monitoring
- Configure alerts in Uptime Kuma
- Set up Grafana dashboards
- Enable notifications in services
- Monitor resource trends

---

**Remember:** Most issues are configuration-related. Double-check `.env` file, permissions, and service-specific configs before assuming hardware issues.

---

[Back to Main README](../README.md) | [Setup Guide](SETUP.md) | [Security Guide](SECURITY.md) | [Best Practices](BEST_PRACTICES.md)
