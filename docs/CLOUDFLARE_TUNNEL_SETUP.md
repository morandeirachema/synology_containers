# CloudFlare Tunnel Setup Guide

## Overview

CloudFlare Tunnel (formerly Argo Tunnel) provides secure remote access to your services **without opening ports** on your router. This significantly improves security by:

- 🔒 **No Port Forwarding**: Eliminate exposed ports 80/443
- 🛡️ **Hide Your IP**: Your home IP address remains private
- ⚡ **DDoS Protection**: CloudFlare's network protects you
- 🔐 **Zero Trust**: Built-in access policies and authentication
- 💰 **Free**: No cost for personal use

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Step-by-Step Setup](#step-by-step-setup)
- [Configuration Options](#configuration-options)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Prerequisites

Before setting up CloudFlare Tunnel, ensure you have:

- ✅ Active CloudFlare account (free tier works)
- ✅ Domain added to CloudFlare
- ✅ Domain DNS managed by CloudFlare
- ✅ This container stack deployed

---

## Architecture Overview

### With CloudFlare Tunnel

```
Internet
    ↓
[CloudFlare Network]
    ↓
CloudFlare Tunnel (Encrypted Outbound Connection)
    ↓
[Your NAS - NO OPEN PORTS]
    ↓
cloudflared container → Traefik → Authelia → Services
```

### Benefits vs Traditional Setup

| Feature | Traditional (Port Forwarding) | CloudFlare Tunnel |
|---------|------------------------------|-------------------|
| **Open Ports** | 80, 443, 51820 exposed | None |
| **IP Exposure** | Home IP visible | Hidden |
| **DDoS Protection** | Limited | CloudFlare network |
| **Setup Complexity** | Router configuration required | Web-based only |
| **Failover** | Manual | Automatic |
| **Cost** | Free | Free |

---

## Step-by-Step Setup

### Step 1: Access CloudFlare Zero Trust Dashboard

1. Go to [CloudFlare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Zero Trust** (or go directly to https://one.dash.cloudflare.com/)
3. If first time, complete the Zero Trust onboarding

### Step 2: Create a Tunnel

1. In Zero Trust dashboard, click **Networks** → **Tunnels**
2. Click **Create a tunnel**
3. Select **Cloudflared** as connector type
4. Click **Next**

### Step 3: Name Your Tunnel

1. Enter a name (e.g., `synology-home-stack`)
2. Click **Save tunnel**

### Step 4: Get Your Tunnel Token

After creating the tunnel, CloudFlare will display installation instructions.

1. **Find the Docker command** that looks like:
   ```bash
   docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token eyJhI...
   ```

2. **Copy the token** (the long string after `--token`)
   - It starts with `eyJ` and is very long
   - This is your `CLOUDFLARE_TUNNEL_TOKEN`

3. **Save this token securely** - you'll need it for the `.env` file

### Step 5: Add Token to Environment File

1. Open your `.env` file:
   ```bash
   nano .env
   ```

2. Add the tunnel token:
   ```bash
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoifQ...
   ```

3. Save and exit (Ctrl+X, Y, Enter)

### Step 6: Configure Tunnel Routes (Public Hostnames)

Back in the CloudFlare Zero Trust dashboard:

1. Click **Public Hostname** tab
2. Click **Add a public hostname**

#### Configure Each Service:

**Homepage:**
- **Subdomain**: `home` (or leave empty for root domain)
- **Domain**: `yourdomain.com`
- **Service Type**: `HTTP`
- **URL**: `traefik:443`
- **Additional settings**:
  - ✅ Enable **No TLS Verify** (since Traefik handles SSL internally)

**Repeat for all services:**

| Service | Subdomain | Service URL | No TLS Verify |
|---------|-----------|-------------|---------------|
| Homepage | home | `http://traefik:80` | ✅ |
| Portainer | portainer | `http://traefik:80` | ✅ |
| Nextcloud | cloud | `http://traefik:80` | ✅ |
| Vaultwarden | vault | `http://traefik:80` | ✅ |
| Pi-hole | dns | `http://traefik:80` | ✅ |
| Grafana | grafana | `http://traefik:80` | ✅ |
| Uptime Kuma | status | `http://traefik:80` | ✅ |
| Dozzle | logs | `http://traefik:80` | ✅ |
| IT-Tools | tools | `http://traefik:80` | ✅ |
| Authelia | auth | `http://traefik:80` | ✅ |
| Traefik | traefik | `http://traefik:80` | ✅ |

**Important Notes:**
- Use `http://traefik:80` (not HTTPS) because Traefik will handle the routing internally
- The "No TLS Verify" option is needed because we're connecting to Traefik's HTTP port internally
- CloudFlare will handle the external HTTPS connection to your users

### Step 7: Deploy CloudFlared Container

1. Start the cloudflared container:
   ```bash
   docker-compose up -d cloudflared
   ```

2. Check logs to verify connection:
   ```bash
   docker-compose logs -f cloudflared
   ```

   You should see:
   ```
   INF Connection registered connIndex=0
   INF Registered tunnel connection
   ```

### Step 8: Verify Tunnel Status

1. Go back to CloudFlare Zero Trust dashboard
2. Navigate to **Networks** → **Tunnels**
3. Your tunnel should show as **HEALTHY** with a green status

### Step 9: Test Access

1. **Close all port forwards** on your router (80, 443, 51820)
2. **From external network** (mobile data), test:
   ```
   https://home.yourdomain.com
   https://vault.yourdomain.com
   ```

3. All services should be accessible without any open ports!

---

## Configuration Options

### Optional: Using Config File Instead of Token

Instead of using the token in environment variables, you can use a config file:

1. Create `config/cloudflared/config.yml`:
   ```yaml
   tunnel: YOUR_TUNNEL_ID
   credentials-file: /etc/cloudflared/credentials.json
   ```

2. Download the credentials JSON from CloudFlare dashboard

3. Update docker-compose.yml:
   ```yaml
   cloudflared:
     volumes:
       - ./config/cloudflared:/etc/cloudflared
     command: tunnel run YOUR_TUNNEL_NAME
   ```

### Advanced: Access Policies

Add authentication policies before reaching your services:

1. In CloudFlare Zero Trust, go to **Access** → **Applications**
2. Click **Add an application**
3. Select **Self-hosted**
4. Configure:
   - **Application name**: e.g., "Home Services"
   - **Session Duration**: 24 hours
   - **Application domain**: `*.yourdomain.com`
5. Add policies:
   - **Allow**: Email addresses ending with `@yourdomain.com`
   - **Require**: Email OTP or other authentication method

This adds an **additional layer of authentication** before even reaching Authelia!

---

## Troubleshooting

### Tunnel shows as INACTIVE

**Solution:**
1. Check container logs:
   ```bash
   docker-compose logs cloudflared
   ```

2. Verify token is correct in `.env` file

3. Restart container:
   ```bash
   docker-compose restart cloudflared
   ```

### Service not accessible via tunnel

**Checklist:**
- [ ] Tunnel status is HEALTHY in CloudFlare dashboard
- [ ] Public hostname configured correctly
- [ ] Service type is `HTTP` (not HTTPS)
- [ ] "No TLS Verify" is enabled
- [ ] Service URL points to `http://traefik:80`
- [ ] Traefik labels are correct on the service
- [ ] Service is running: `docker-compose ps`

### "502 Bad Gateway" errors

This usually means CloudFlare Tunnel can reach Traefik, but Traefik can't route to the service.

**Solutions:**
1. Verify service is running:
   ```bash
   docker-compose ps | grep servicename
   ```

2. Check Traefik routing:
   ```bash
   docker-compose logs traefik | grep servicename
   ```

3. Test internal connectivity:
   ```bash
   docker exec cloudflared wget -O- http://traefik:80
   ```

### Slow performance

**Optimizations:**
1. Enable **Argo Smart Routing** (paid, but minimal cost)
2. Use **HTTP/2** in Traefik configuration
3. Enable **Compression** in Traefik middleware
4. Check CloudFlare **Speed** settings (Brotli, Auto Minify)

---

## FAQ

### Do I still need Traefik with CloudFlare Tunnel?

**Yes!** Traefik still handles:
- Internal routing to services
- SSL/TLS within your network (defense in depth)
- Load balancing
- Middleware (authentication, headers, etc.)

CloudFlare Tunnel replaces the **external entry point**, not the internal routing.

### Can I use both CloudFlare Tunnel AND WireGuard?

**Absolutely!** Recommended setup:
- **CloudFlare Tunnel**: For web services (HTTPS)
- **WireGuard**: For direct network access (SSH, SMB, etc.)

WireGuard still requires port 51820 forwarded, but you can close 80/443.

### What about Let's Encrypt certificates?

With CloudFlare Tunnel:
- CloudFlare handles external SSL (automatic)
- You can still use Let's Encrypt for internal access
- Or switch to CloudFlare Origin Certificates for internal SSL

### Is CloudFlare Tunnel really free?

**Yes!** Free tier includes:
- Unlimited tunnels
- Unlimited traffic
- Basic DDoS protection
- 50 users for Access policies

Paid features (optional):
- Argo Smart Routing ($0.10/GB)
- Advanced bot protection
- More Access users

### Can I self-host the tunnel software?

CloudFlare Tunnel must connect to CloudFlare's network, but the `cloudflared` daemon runs on **your infrastructure** (in this case, in a Docker container). Your data flows through CloudFlare's network but is **end-to-end encrypted**.

### What if CloudFlare goes down?

- **CloudFlare outages are rare** (99.99%+ uptime)
- If CloudFlare is down, external access won't work
- **Local access still works** via IP addresses or WireGuard
- **Backup solution**: Keep WireGuard configured as failover

---

## Next Steps

1. ✅ Set up tunnel (completed if you followed this guide)
2. 📖 Configure [Access Policies](https://developers.cloudflare.com/cloudflare-one/policies/access/) for additional security
3. 📊 Monitor tunnel health in CloudFlare dashboard
4. 🔒 Consider enabling [CloudFlare Access](https://www.cloudflare.com/products/zero-trust/access/) for enterprise-grade authentication
5. ⚡ Optional: Enable [Argo Smart Routing](https://www.cloudflare.com/products/argo-smart-routing/) for better performance

---

## Additional Resources

- **Official Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Troubleshooting**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/remote/
- **Access Policies**: https://developers.cloudflare.com/cloudflare-one/policies/access/
- **Community**: https://community.cloudflare.com/c/security/cloudflare-one/

---

---

[Back to Main README](../README.md) | [Security Guide](SECURITY.md) | [Best Practices](BEST_PRACTICES.md)
