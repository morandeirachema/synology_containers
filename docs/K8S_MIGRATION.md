# Kubernetes Migration Guide

This guide covers migrating services from Docker Compose to Kubernetes on the Talos cluster.

## Overview

Migration from Docker to Kubernetes involves:
1. Converting Docker Compose configurations to Kubernetes manifests
2. Adapting storage from local Docker volumes to NFS PersistentVolumes
3. Updating networking (Traefik → Cilium Ingress)
4. Configuring secrets management (env files → Conjur/External Secrets)

## Migration Strategy

### Recommended Approach: Parallel Operation

Run Docker and Kubernetes side-by-side during migration:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Migration Timeline                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Phase 1: Kubernetes Ready          Phase 2: Service Migration           │
│  ─────────────────────────          ──────────────────────────           │
│                                                                           │
│  ┌─────────────────────────┐       ┌─────────────────────────┐          │
│  │ Docker (Primary)        │       │ Docker (Legacy)         │          │
│  │ • All services running  │  ───▶ │ • Pi-hole only          │          │
│  │ • Traefik routing       │       │ • DNS service           │          │
│  └─────────────────────────┘       └─────────────────────────┘          │
│                                                                           │
│  ┌─────────────────────────┐       ┌─────────────────────────┐          │
│  │ Kubernetes (Testing)    │       │ Kubernetes (Primary)    │          │
│  │ • Infrastructure only   │  ───▶ │ • All services migrated │          │
│  │ • ArgoCD, monitoring    │       │ • Cilium routing        │          │
│  └─────────────────────────┘       └─────────────────────────┘          │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Migration Order

**Phase 1: Infrastructure (Week 1)**
1. ✅ Kubernetes cluster deployed
2. ✅ ArgoCD configured
3. ✅ Monitoring stack (Prometheus, Grafana, Loki)
4. ✅ cert-manager with Let's Encrypt
5. ✅ Conjur secrets management

**Phase 2: Stateless Services (Week 2)**
1. Homepage dashboard
2. IT-Tools
3. Uptime Kuma (with data migration)

**Phase 3: Authentication (Week 3)**
1. Authelia (export/import users)
2. Traefik → Cilium Ingress transition

**Phase 4: Stateful Services (Week 4)**
1. Vaultwarden (backup first!)
2. Nextcloud (data migration)

**Phase 5: Final Migration**
1. Cut over DNS
2. Decommission Docker services
3. Keep Pi-hole on Docker (recommended)

---

## Service Migration Templates

### Converting Docker Compose to Kubernetes

#### Example: Homepage Dashboard

**Docker Compose (`docker-compose.yml`):**
```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    ports:
      - "3000:3000"
    volumes:
      - ./config/homepage:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=1000
      - PGID=1000
    restart: unless-stopped
```

**Kubernetes Manifest (`k8s/base/homepage/deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homepage
  namespace: homepage
  labels:
    app: homepage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: homepage
  template:
    metadata:
      labels:
        app: homepage
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: homepage
          image: ghcr.io/gethomepage/homepage:latest
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: config
              mountPath: /app/config
            - name: tmp
              mountPath: /tmp
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: homepage-config
        - name: tmp
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: homepage
  namespace: homepage
spec:
  selector:
    app: homepage
  ports:
    - port: 80
      targetPort: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: homepage
  namespace: homepage
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: cilium
  rules:
    - host: home.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: homepage
                port:
                  number: 80
  tls:
    - hosts:
        - home.yourdomain.com
      secretName: homepage-tls
```

---

## Data Migration Procedures

### Vaultwarden Migration

**1. Backup Current Data:**
```bash
# On Synology
cd /volume1/docker/vaultwarden
docker exec vaultwarden /bin/sh -c "sqlite3 /data/db.sqlite3 '.backup /data/backup.sqlite3'"
cp -r data vaultwarden-backup-$(date +%Y%m%d)
```

**2. Create PVC and Copy Data:**
```bash
# Create PVC
kubectl apply -f k8s/base/vaultwarden/pvc.yaml

# Copy data to NFS
cp -r /volume1/docker/vaultwarden/data/* /volume1/k8s-pv/vaultwarden/
```

**3. Deploy to Kubernetes:**
```bash
kubectl apply -k k8s/base/vaultwarden/
```

**4. Verify:**
```bash
kubectl logs -n vaultwarden deployment/vaultwarden
kubectl port-forward -n vaultwarden svc/vaultwarden 8080:80
# Test login at http://localhost:8080
```

### Nextcloud Migration

**1. Put Nextcloud in Maintenance Mode:**
```bash
docker exec -u www-data nextcloud php occ maintenance:mode --on
```

**2. Backup Database:**
```bash
docker exec nextcloud-db mysqldump -u nextcloud -p nextcloud > nextcloud-db-backup.sql
```

**3. Copy Files:**
```bash
cp -r /volume1/docker/nextcloud/data /volume1/k8s-pv/nextcloud/
cp -r /volume1/docker/nextcloud/config /volume1/k8s-pv/nextcloud/
```

**4. Deploy to Kubernetes:**
```bash
# Deploy database first
kubectl apply -k k8s/base/nextcloud/mariadb/

# Wait for database
kubectl wait --for=condition=ready pod -l app=nextcloud-db -n nextcloud --timeout=300s

# Deploy Nextcloud
kubectl apply -k k8s/base/nextcloud/
```

**5. Restore Database:**
```bash
kubectl exec -n nextcloud nextcloud-db-0 -- mysql -u nextcloud -p nextcloud < nextcloud-db-backup.sql
```

**6. Complete Migration:**
```bash
kubectl exec -n nextcloud deployment/nextcloud -- php occ maintenance:mode --off
kubectl exec -n nextcloud deployment/nextcloud -- php occ upgrade
```

---

## DNS Cutover

### Gradual DNS Migration

**1. Lower TTL (1 week before):**
```bash
# In CloudFlare or DNS provider
# Change TTL from 3600 to 60 seconds
```

**2. Update DNS Records:**
```bash
# Point services to new Kubernetes Ingress IP
# Old: A record → 192.168.1.5 (Docker/Traefik)
# New: A record → 192.168.1.210 (K8s/Cilium Ingress)
```

**3. Monitor Traffic:**
```bash
# Check Traefik access logs (Docker)
docker logs traefik --tail 100 -f

# Check Cilium Ingress logs (Kubernetes)
kubectl logs -n kube-system -l k8s-app=cilium -f | grep ingress
```

---

## Rollback Procedures

### Quick Rollback to Docker

If issues occur during migration:

**1. Update DNS:**
```bash
# Revert A records to Docker IP (192.168.1.5)
```

**2. Scale Down Kubernetes:**
```bash
kubectl scale deployment --all --replicas=0 -n <namespace>
```

**3. Verify Docker Services:**
```bash
docker ps
docker-compose ps
```

---

## Post-Migration Checklist

- [ ] All services accessible via new Ingress
- [ ] SSL certificates valid
- [ ] Authentication working (Authelia)
- [ ] Data persisted correctly
- [ ] Monitoring showing metrics
- [ ] Logs flowing to Loki
- [ ] Backups configured (Velero)
- [ ] DNS TTL restored to normal (3600)
- [ ] Old Docker containers stopped
- [ ] Docker volumes archived

---

## Keeping Pi-hole on Docker

**Recommendation:** Keep Pi-hole running on Docker (Synology) instead of migrating to Kubernetes.

**Reasons:**
1. DNS is critical infrastructure - shouldn't depend on K8s cluster
2. If Kubernetes goes down, DNS still works
3. Simpler DNS resolution for internal services
4. No chicken-and-egg problem during K8s bootstrap

**Configuration:**
```yaml
# Pi-hole stays on Docker at 192.168.1.5:53
# Kubernetes nodes use Pi-hole for DNS
# Pi-hole resolves *.yourdomain.com to K8s Ingress IP (192.168.1.210)
```

---

## References

- [K8s Architecture](K8S_ARCHITECTURE.md)
- [K8s Operations](K8S_OPERATIONS.md)
- [Talos Setup Guide](TALOS_KUBERNETES_SETUP.md)
- [Infrastructure as Code](INFRASTRUCTURE_AS_CODE.md)

---

**Last Updated**: 2025-12-09

[Back to Main README](../README.md) | [K8s Manifests](../k8s/README.md) | [Secrets Management](SECRETS_MANAGEMENT.md)
