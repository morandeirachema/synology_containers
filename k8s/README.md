# Kubernetes Manifests

Kubernetes manifests organized using **Kustomize** for deploying the home stack on the Talos Kubernetes cluster.

**Last Updated**: 2025-12-09

---

## Directory Structure

```
k8s/
├── base/                          # Base configurations (reusable)
│   ├── traefik/                  # Traefik ingress controller
│   ├── authelia/                 # Authelia SSO & 2FA
│   ├── vaultwarden/              # Vaultwarden password manager
│   ├── nextcloud/                # Nextcloud file storage
│   ├── homepage/                 # Homepage dashboard
│   └── it-tools/                 # IT-Tools utilities
│
├── overlays/                      # Environment-specific overlays
│   ├── production/               # Production configuration
│   ├── staging/                  # Staging configuration
│   └── dev/                      # Development configuration
│
├── infrastructure/                # Core infrastructure
│   ├── external-secrets/         # Conjur secrets management
│   ├── nfs-provisioner/          # NFS storage provisioner
│   ├── monitoring/               # Prometheus + Grafana
│   ├── logging/                  # Loki + Promtail
│   └── velero/                   # Backup and restore
│
└── bootstrap/                     # Initial cluster setup
    ├── argocd/                   # ArgoCD GitOps
    ├── cilium/                   # Cilium CNI
    ├── cert-manager/             # Certificate management
    └── metallb/                  # Load balancer
```

---

## Quick Start

### 1. Deploy Infrastructure (Bootstrap)

```bash
# Deploy ArgoCD first
kubectl apply -k k8s/bootstrap/argocd/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Deploy other infrastructure components
kubectl apply -k k8s/bootstrap/cilium/
kubectl apply -k k8s/bootstrap/cert-manager/
kubectl apply -k k8s/bootstrap/metallb/
kubectl apply -k k8s/infrastructure/nfs-provisioner/
kubectl apply -k k8s/infrastructure/external-secrets/
```

### 2. Deploy Applications

#### Option A: Deploy All Production Services

```bash
kubectl apply -k k8s/overlays/production/
```

#### Option B: Deploy Individual Services

```bash
# Deploy just Traefik
kubectl apply -k k8s/base/traefik/

# Deploy Homepage dashboard
kubectl apply -k k8s/base/homepage/

# Deploy IT-Tools
kubectl apply -k k8s/base/it-tools/
```

### 3. Verify Deployment

```bash
# Check all pods
kubectl get pods -A

# Check ingresses
kubectl get ingress -A

# Check certificates
kubectl get certificates -A
```

---

## Using Kustomize Overlays

Kustomize allows you to maintain a **single base configuration** and create environment-specific variations without duplicating code.

### Production Deployment

**Features:**
- High availability (3 replicas for Traefik, Authelia)
- Pinned image versions for stability
- Higher resource limits
- All services enabled

**Deploy:**
```bash
kubectl apply -k k8s/overlays/production/
```

**Customize:**
Edit `k8s/overlays/production/kustomization.yaml` to:
- Change image tags
- Adjust replica counts
- Modify resource limits

### Staging Deployment

**Features:**
- Latest images (for testing updates)
- Minimal replicas (1 each)
- Staging subdomain
- Lower resource usage

**Deploy:**
```bash
kubectl apply -k k8s/overlays/staging/
```

### Development Deployment

**Features:**
- Only lightweight services (Homepage, IT-Tools)
- Single replica
- Minimal resources
- Fast iteration

**Deploy:**
```bash
kubectl apply -k k8s/overlays/dev/
```

---

## Available Base Applications

### 1. **Traefik** (`k8s/base/traefik/`)

Ingress controller with automatic HTTPS, security headers, and rate limiting.

**Features:**
- CloudFlare DNS challenge for Let's Encrypt
- Security middleware (headers, compression, rate-limiting)
- Dashboard with Authelia protection
- Prometheus metrics

**Deploy:**
```bash
# Edit cloudflare credentials
kubectl create secret generic cloudflare-api-credentials \
  -n traefik \
  --from-literal=email=admin@yourdomain.com \
  --from-literal=apiKey=YOUR_CLOUDFLARE_API_KEY

kubectl apply -k k8s/base/traefik/
```

**Access:** https://traefik.yourdomain.com

---

### 2. **Authelia** (`k8s/base/authelia/`)

Single Sign-On (SSO) and Two-Factor Authentication (2FA) for all services.

**Features:**
- PostgreSQL backend for user sessions
- Redis for session caching
- TOTP + WebAuthn support
- SMTP notifications

**Deploy:**
```bash
# Create secret files
mkdir -p k8s/base/authelia/secrets
openssl rand -base64 32 > k8s/base/authelia/secrets/jwt-secret.txt
openssl rand -base64 32 > k8s/base/authelia/secrets/session-secret.txt
openssl rand -base64 64 > k8s/base/authelia/secrets/storage-encryption-key.txt
echo "YOUR_SMTP_PASSWORD" > k8s/base/authelia/secrets/smtp-password.txt
echo "YOUR_POSTGRES_PASSWORD" > k8s/base/authelia/secrets/postgres-password.txt

kubectl apply -k k8s/base/authelia/
```

**Access:** https://auth.yourdomain.com

---

### 3. **Vaultwarden** (`k8s/base/vaultwarden/`)

Password manager (Bitwarden-compatible server).

**Features:**
- PostgreSQL database backend
- WebSocket support for real-time sync
- SMTP email notifications
- Admin panel

**Deploy:**
```bash
# Edit secrets in k8s/base/vaultwarden/kustomization.yaml
kubectl apply -k k8s/base/vaultwarden/
```

**Access:** https://vault.yourdomain.com

---

### 4. **Nextcloud** (`k8s/base/nextcloud/`)

File storage and collaboration platform.

**Features:**
- PostgreSQL database
- Redis caching for performance
- Multiple persistent volumes (data, config, apps, themes)
- Large file upload support

**Deploy:**
```bash
kubectl apply -k k8s/base/nextcloud/
```

**Access:** https://cloud.yourdomain.com

---

### 5. **Homepage** (`k8s/base/homepage/`)

Beautiful dashboard for your Kubernetes cluster and services.

**Features:**
- Kubernetes integration (shows cluster stats)
- Service monitoring
- Customizable bookmarks
- RBAC for K8s API access

**Deploy:**
```bash
kubectl apply -k k8s/base/homepage/
```

**Access:** https://home.yourdomain.com

---

### 6. **IT-Tools** (`k8s/base/it-tools/`)

Developer utilities (base64 encode/decode, JSON formatter, etc.).

**Deploy:**
```bash
kubectl apply -k k8s/base/it-tools/
```

**Access:** https://tools.yourdomain.com

---

## Customization Guide

### Modify Base Configuration

**Example: Change Traefik replicas**

```yaml
# k8s/base/traefik/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

replicas:
  - name: traefik
    count: 3  # Change this
```

### Create Custom Overlay

**Example: Create a "home" overlay for minimal services**

```bash
mkdir -p k8s/overlays/home
```

```yaml
# k8s/overlays/home/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base/homepage
  - ../../base/it-tools
  - ../../base/vaultwarden

namespace: home

commonLabels:
  environment: home
```

**Deploy:**
```bash
kubectl apply -k k8s/overlays/home/
```

---

## Secrets Management

**Full Guide**: [docs/SECRETS_MANAGEMENT.md](../docs/SECRETS_MANAGEMENT.md)

### Option 1: Kustomize Secret Generator (Development)

```yaml
# In kustomization.yaml
secretGenerator:
  - name: my-secret
    literals:
      - username=admin
      - password=secret123
```

### Option 2: Environment Files

```yaml
# In kustomization.yaml
secretGenerator:
  - name: cloudflare-api-credentials
    envs:
      - cloudflare-credentials.env  # Git-ignored
    options:
      disableNameSuffixHash: true
```

### Option 3: External Secrets Operator + Conjur (Production)

See `k8s/infrastructure/external-secrets/README.md` for Conjur setup.

```yaml
# example-external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  secretStoreRef:
    name: conjur
    kind: SecretStore
  data:
    - secretKey: password
      remoteRef:
        key: k8s-secrets/database/password
```

---

## Monitoring and Logging

### Prometheus + Grafana

```bash
kubectl apply -k k8s/infrastructure/monitoring/
```

**Access:**
- Grafana: https://grafana.yourdomain.com
- Prometheus: https://prometheus.yourdomain.com

### Loki + Promtail

```bash
kubectl apply -k k8s/infrastructure/logging/
```

Logs accessible via Grafana → Explore → Loki

---

## GitOps with ArgoCD

After deploying ArgoCD, you can manage everything declaratively:

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/synology_containers
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Apply:**
```bash
kubectl apply -f argocd-app.yaml
```

Now ArgoCD will automatically sync your Git repository to the cluster!

---

## Common Operations

### Update Image Tag

```bash
cd k8s/overlays/production
kustomize edit set image vaultwarden/server:1.30.5-alpine

kubectl apply -k .
```

### Scale Deployment

```bash
kubectl scale deployment traefik --replicas=5 -n traefik
```

### View Generated Manifests (Dry-Run)

```bash
kubectl kustomize k8s/overlays/production/ > production-manifests.yaml
```

### Diff Before Apply

```bash
kubectl diff -k k8s/overlays/production/
```

---

## Troubleshooting

### Check Kustomize Build

```bash
kubectl kustomize k8s/overlays/production/
```

### Validate Manifests

```bash
kubectl apply --dry-run=client -k k8s/overlays/production/
```

### Check Resource Status

```bash
kubectl get all -n production
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -n production
```

### Common Issues

**Issue: Secret not found**
```bash
# Check if secret exists
kubectl get secrets -n production

# Recreate secret
kubectl delete secret my-secret -n production
kubectl apply -k k8s/base/myapp/
```

**Issue: Image pull errors**
```bash
# Check image name/tag
kubectl describe pod <pod-name> -n production | grep Image

# Update image tag in kustomization.yaml
```

**Issue: Ingress not working**
```bash
# Check ingress
kubectl get ingress -n production
kubectl describe ingress <ingress-name> -n production

# Check cert-manager certificates
kubectl get certificates -n production
```

---

## Next Steps

1. **Customize domain names**: Replace `yourdomain.com` in all ingress files
2. **Configure secrets**: Update all `secretGenerator` sections with real values
3. **Set up Conjur**: Follow `k8s/infrastructure/external-secrets/README.md`
4. **Configure backups**: Deploy Velero (`k8s/infrastructure/velero/`)
5. **Set up monitoring**: Deploy Prometheus + Grafana stack
6. **Enable GitOps**: Configure ArgoCD to watch your Git repository

---

## Related Documentation

- [Talos Kubernetes Setup Guide](../docs/TALOS_KUBERNETES_SETUP.md)
- [Kubernetes Architecture](../docs/K8S_ARCHITECTURE.md)
- [Operations Guide](../docs/K8S_OPERATIONS.md)
- [Secrets Management Guide](../docs/SECRETS_MANAGEMENT.md)
- [Conjur Setup Details](./infrastructure/external-secrets/README.md)
- [Kustomize Official Docs](https://kustomize.io/)

---

[Back to Main README](../README.md) | [Talos Setup](../docs/TALOS_KUBERNETES_SETUP.md) | [Architecture](../docs/K8S_ARCHITECTURE.md)

---

## Architecture Decision

**Why only Pi-hole on Docker?**

Pi-hole stays on the Synology Docker stack because:
- **DNS is critical**: If K8s cluster has issues, you still have DNS
- **Avoid circular dependency**: K8s nodes rely on Pi-hole for DNS resolution
- **Simplicity**: Pi-hole is simple and stable on Docker
- **Single point of failure**: Better to have DNS outside the cluster

Everything else runs on Kubernetes for:
- **Scalability**: Easy horizontal scaling
- **Self-healing**: Automatic pod restarts
- **Rolling updates**: Zero-downtime deployments
- **Resource efficiency**: Better bin-packing
- **Cloud-native**: Modern best practices
- **Learning**: Hands-on K8s experience

---

**Questions?** Check the main documentation or open an issue!
