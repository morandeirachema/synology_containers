# Service Migration Guide: Docker → Kubernetes

This guide helps you decide which services to migrate from your Docker stack to Kubernetes, and provides migration strategies for each service type.

---

## Table of Contents

- [Migration Strategy](#migration-strategy)
- [Service Assessment](#service-assessment)
- [Keep on Docker](#keep-on-docker)
- [Migrate to Kubernetes](#migrate-to-kubernetes)
- [Migration Procedures](#migration-procedures)
- [Rollback Plan](#rollback-plan)
- [Best Practices](#best-practices)

---

## Migration Strategy

### Philosophy: Gradual Migration

**DO NOT** migrate everything at once. Follow this approach:

1. **Phase 1 (Months 1-2)**: Run both stacks in parallel, migrate stateless services
2. **Phase 2 (Months 3-4)**: Migrate semi-stateful services with good backups
3. **Phase 3 (Months 5-6)**: Evaluate critical services, keep some on Docker permanently
4. **Phase 4 (Ongoing)**: New services go to Kubernetes by default

### Decision Criteria

**Migrate to K8s if:**
- ✅ Stateless or easily replicated
- ✅ Cloud-native architecture
- ✅ Benefits from auto-scaling
- ✅ Needs zero-downtime deployments
- ✅ You want to learn K8s with it
- ✅ Part of microservices architecture

**Keep on Docker if:**
- ❌ Highly stateful with complex data
- ❌ Tight coupling to Synology features
- ❌ Mission-critical (don't fix what isn't broken)
- ❌ Complex networking requirements
- ❌ Vendor-specific implementation
- ❌ Would require significant refactoring

---

## Service Assessment

### Current Docker Stack Analysis

| Service | Type | State | Complexity | Recommendation |
|---------|------|-------|------------|----------------|
| **Traefik** | Reverse Proxy | Stateless | Low | ⚠️ **Keep** (edge proxy for both) |
| **CloudFlared** | Tunnel | Stateless | Low | ⚠️ **Keep** or Migrate |
| **Authelia** | Authentication | Semi-stateful | Medium | ⚠️ **Keep** (critical path) |
| **WireGuard** | VPN | Stateless | Low | ⚠️ **Keep** (network critical) |
| **Vaultwarden** | Password Manager | Stateful | Medium | ❌ **Keep** (too critical) |
| **Pi-hole** | DNS | Semi-stateful | Low | ❌ **Keep** (DNS critical) |
| **Nextcloud** | File Storage | Highly Stateful | High | ❌ **Keep** (complex, Synology-optimized) |
| **Nextcloud DB** | Database | Stateful | Medium | ❌ **Keep** (with Nextcloud) |
| **Portainer** | Docker Management | Stateless | Low | ❌ **Keep** (manages Docker) |
| **Uptime Kuma** | Monitoring | Semi-stateful | Low | ✅ **Migrate** (Prometheus replaces) |
| **Grafana** | Dashboards | Semi-stateful | Low | ✅ **Migrate** (K8s has own Grafana) |
| **Prometheus** | Metrics | Stateful | Medium | ✅ **Migrate** (K8s native) |
| **cAdvisor** | Metrics | Stateless | Low | ✅ **Migrate** (built into K8s) |
| **Homepage** | Dashboard | Stateless | Low | ✅ **Migrate** (good learning project) |
| **Diun** | Update Notifier | Stateless | Low | ✅ **Migrate** or use Renovate |
| **Dozzle** | Log Viewer | Stateless | Low | ✅ **Migrate** (Loki replaces) |
| **IT-Tools** | Utilities | Stateless | Low | ✅ **Migrate** (perfect for K8s) |

---

## Keep on Docker

### Services to Keep on Docker Stack

#### 1. **Traefik (Edge Proxy)**

**Reason to Keep:**
- Single entry point for both Docker and K8s
- Already configured with CloudFlare
- Handles SSL for both stacks
- Mission-critical, no downtime tolerance

**Architecture:**
```
Internet → Traefik (Docker)
            ├→ Docker Services (*.yourdomain.com)
            └→ K8s Ingress (*.k8s.yourdomain.com)
```

**Alternative:** Run separate ingress, use DNS-based routing

#### 2. **Authelia (2FA)**

**Reason to Keep:**
- Authentication is critical path
- Complex configuration already working
- Single source of truth for auth
- Integrates with both Docker and K8s

**Future Migration:** Possible with Keycloak or Dex on K8s

#### 3. **Vaultwarden (Password Manager)**

**Reason to Keep:**
- Too critical to risk migration issues
- SQLite database works perfectly on Docker
- Synology provides reliable storage
- Already has proper backups

**Security Note:** This is your password vault—stability > experimentation

#### 4. **Pi-hole (DNS)**

**Reason to Keep:**
- DNS must be highly available
- Network-critical service
- Simple and works perfectly on Docker
- Migration complexity not worth the benefit

**Alternative:** Could run Pi-hole on K8s, but DNS chicken-and-egg issues

#### 5. **Nextcloud + MariaDB**

**Reason to Keep:**
- Highly stateful with complex data model
- Optimized for Synology storage
- Large data volumes
- Complex upgrade path
- Mission-critical file storage

**Note:** Nextcloud on K8s is possible but complex. Not worth it unless you need horizontal scaling.

#### 6. **Portainer**

**Reason to Keep:**
- Manages Docker containers
- No benefit from being on K8s
- You'll still have Docker stack

**K8s Alternative:** Already have ArgoCD and kubectl for K8s management

#### 7. **WireGuard VPN**

**Reason to Keep:**
- Requires host networking
- Simpler to manage on Docker
- Network-critical service

**Alternative:** Could migrate to K8s with proper network policies, but adds complexity

---

## Migrate to Kubernetes

### Phase 1: Easy Wins (Stateless Services)

#### 1. **IT-Tools** (Stateless Utilities)

**Difficulty:** ⭐☆☆☆☆ (Easiest)

**Migration Steps:**

1. Create namespace:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tools
```

2. Create deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: it-tools
  namespace: tools
spec:
  replicas: 2
  selector:
    matchLabels:
      app: it-tools
  template:
    metadata:
      labels:
        app: it-tools
    spec:
      containers:
        - name: it-tools
          image: corentinth/it-tools:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
```

3. Create service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: it-tools
  namespace: tools
spec:
  selector:
    app: it-tools
  ports:
    - port: 80
      targetPort: 80
```

4. Create ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: it-tools
  namespace: tools
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: cilium
  rules:
    - host: tools.k8s.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: it-tools
                port:
                  number: 80
  tls:
    - hosts:
        - tools.k8s.yourdomain.com
      secretName: it-tools-tls
```

5. Deploy:
```bash
kubectl apply -f it-tools-deployment.yaml
```

6. Test and verify, then remove from Docker:
```bash
# In docker-compose.yml, comment out IT-Tools
docker-compose down it-tools
```

#### 2. **Homepage Dashboard**

**Difficulty:** ⭐⭐☆☆☆

**Benefits:**
- Learn K8s ConfigMaps
- Practice with persistent volumes
- Good intro to StatefulSets

**Migration Steps:**

Create `k8s/apps/production/homepage/`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: homepage-config
  namespace: production
data:
  settings.yaml: |
    title: Kubernetes Home Stack
    theme: dark
    # ... copy from Docker config

  services.yaml: |
    - Kubernetes Services:
        - ArgoCD:
            href: https://argocd.k8s.yourdomain.com
            description: GitOps
        # ... add other K8s services

  widgets.yaml: |
    - kubernetes:
        cluster:
          show: true
          cpu: true
          memory: true
    # ... etc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homepage
  namespace: production
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
      serviceAccountName: homepage
      containers:
        - name: homepage
          image: ghcr.io/benphelps/homepage:latest
          ports:
            - containerPort: 3000
          volumeMounts:
            - name: config
              mountPath: /app/config
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: config
          configMap:
            name: homepage-config
---
# ServiceAccount for Homepage to query K8s API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: homepage
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: homepage
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "nodes"]
    verbs: ["get", "list"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: homepage
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: homepage
subjects:
  - kind: ServiceAccount
    name: homepage
    namespace: production
```

### Phase 2: Monitoring Stack

The K8s cluster already has Prometheus + Grafana + Loki. These replace:
- Uptime Kuma → Prometheus AlertManager
- Grafana (Docker) → Grafana (K8s)
- Dozzle → Loki + Grafana

**Migration:** Already done! Just point to new Grafana.

#### Replace Uptime Kuma with Prometheus Monitoring

Instead of Uptime Kuma, use Prometheus blackbox exporter:

```yaml
# k8s/infrastructure/monitoring/blackbox-exporter.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-config
  namespace: monitoring
data:
  blackbox.yml: |
    modules:
      http_2xx:
        prober: http
        timeout: 5s
        http:
          valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
          valid_status_codes: []
          method: GET
          preferred_ip_protocol: "ip4"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blackbox-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blackbox-exporter
  template:
    metadata:
      labels:
        app: blackbox-exporter
    spec:
      containers:
        - name: blackbox-exporter
          image: prom/blackbox-exporter:latest
          args:
            - --config.file=/config/blackbox.yml
          ports:
            - containerPort: 9115
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: blackbox-config
---
# Prometheus ServiceMonitor to scrape endpoints
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: blackbox-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: blackbox-exporter
  endpoints:
    - port: http
      interval: 30s
```

Configure Prometheus to monitor services:

```yaml
# Add to Prometheus configuration
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
        - https://vault.yourdomain.com
        - https://cloud.yourdomain.com
        - https://tools.k8s.yourdomain.com
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter:9115
```

### Phase 3: Optional Migrations

#### CloudFlare Tunnel → K8s

If you want to migrate CloudFlared to K8s:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: infrastructure
spec:
  replicas: 2  # HA
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          command:
            - cloudflared
            - tunnel
            - run
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflare-tunnel
                  key: token
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-tunnel
  namespace: infrastructure
type: Opaque
stringData:
  token: YOUR_TUNNEL_TOKEN_HERE
```

---

## Migration Procedures

### Pre-Migration Checklist

- [ ] Service is backed up
- [ ] Migration tested in staging
- [ ] Rollback plan documented
- [ ] Downtime window scheduled (if needed)
- [ ] Team notified
- [ ] Monitoring configured for new service

### Standard Migration Process

1. **Deploy to K8s (parallel)**
   - Deploy service on K8s with different subdomain
   - Example: `tools-new.k8s.yourdomain.com`

2. **Test & Verify**
   - Functional testing
   - Performance testing
   - Load testing (if applicable)

3. **Cutover**
   - Update DNS/Ingress to point to K8s service
   - Monitor for issues

4. **Cleanup**
   - Keep Docker version running for 1 week
   - Remove from `docker-compose.yml`
   - Delete Docker volumes (after final backup)

### Zero-Downtime Migration

For services that must have zero downtime:

1. Run both versions in parallel
2. Use weighted routing (if supported)
3. Gradually shift traffic: 10% → 50% → 100%
4. Monitor metrics closely
5. Instant rollback capability

---

## Rollback Plan

### Immediate Rollback (< 1 hour)

If K8s migration fails:

```bash
# 1. Update DNS/Ingress back to Docker
kubectl patch ingress <service-name> -n <namespace> \
  --type=json -p='[{"op": "remove", "path": "/spec/rules"}]'

# 2. Restart Docker service
cd /path/to/synology_containers
docker-compose up -d <service-name>

# 3. Verify
curl https://service.yourdomain.com
```

### Data Rollback

If data corruption or loss:

```bash
# 1. Stop K8s service
kubectl scale deployment <service-name> --replicas=0 -n <namespace>

# 2. Restore from Velero backup
velero restore create --from-backup <backup-name>

# 3. Verify data
kubectl logs <pod-name> -n <namespace>

# 4. Scale back up
kubectl scale deployment <service-name> --replicas=2 -n <namespace>
```

---

## Best Practices

### 1. Start Simple

Begin with stateless services that are:
- Not critical
- Easy to redeploy
- Low traffic
- Standalone (no dependencies)

**Example:** IT-Tools is perfect first migration

### 2. Test Everything

```bash
# Before migration
./scripts/test-service.sh docker-service

# After migration
./scripts/test-service.sh k8s-service

# Compare results
```

### 3. Monitor Closely

Add specific alerts for newly migrated services:
- Response time
- Error rate
- Resource usage
- Restart count

### 4. Document Differences

Create `MIGRATION_LOG.md` documenting:
- What changed
- Configuration differences
- Performance differences
- Issues encountered
- Lessons learned

### 5. Keep Docker Stack Lean

After successful migrations:
- Remove unused services
- Consolidate remaining services
- Update documentation
- Reduce resource reservations

---

## Migration Timeline Example

### Month 1: Foundation
- Week 1-2: K8s cluster setup and testing
- Week 3: Deploy IT-Tools to K8s
- Week 4: Deploy Homepage to K8s

### Month 2: Observability
- Week 1: Configure Prometheus monitoring
- Week 2: Set up Loki logging
- Week 3: Create Grafana dashboards
- Week 4: Remove Uptime Kuma, Dozzle from Docker

### Month 3: Evaluation
- Review what's working
- Decide on further migrations
- Optimize resource usage
- Update documentation

### Month 4+: Steady State
- New services go to K8s by default
- Keep core services on Docker
- Focus on Day-2 operations

---

## Conclusion

**Remember:**
- Not everything needs to be migrated
- Docker stack is production-proven and stable
- Kubernetes is great for new, cloud-native workloads
- Both can coexist indefinitely

**Success Metrics:**
- Zero data loss
- Minimal downtime
- Improved observability
- Learning objectives met
- Both stacks running smoothly

---

[Back to Main README](../README.md) | [Setup Guide](TALOS_KUBERNETES_SETUP.md) | [Operations Guide](K8S_OPERATIONS.md)
