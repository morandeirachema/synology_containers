# Secrets Management Guide

This guide covers secrets management strategies for the Kubernetes cluster, from simple Kustomize-based secrets to enterprise-grade Conjur integration.

## Overview

The repository supports three secrets management approaches:

| Approach | Complexity | Use Case |
|----------|------------|----------|
| Kustomize SecretGenerator | Low | Development, small deployments |
| Environment files (.env) | Low | Simple key-value secrets |
| Conjur + External Secrets Operator | High | Production, enterprise, compliance |

## Quick Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Secrets Management Options                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Kustomize (Simple)              Conjur + ESO (Enterprise)              │
│  ──────────────────              ────────────────────────               │
│  • Secrets in kustomization.yaml  • Centralized vault                   │
│  • No external dependencies       • Policy-based access control         │
│  • Manual rotation                • Auto-rotation support               │
│  • Good for dev/test              • Audit logging                       │
│                                   • Good for production                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Method 1: Kustomize SecretGenerator

### How It Works

Kustomize generates Kubernetes Secrets at deployment time from literals or files.

### Configuration

In `kustomization.yaml`:

```yaml
secretGenerator:
  - name: my-app-secrets
    literals:
      - database-password=YOUR_PASSWORD
      - api-key=YOUR_API_KEY
    options:
      disableNameSuffixHash: true
```

Or from files:

```yaml
secretGenerator:
  - name: my-app-secrets
    files:
      - secrets/jwt-secret
      - secrets/encryption-key
```

### Usage in Deployments

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-app-secrets
        key: database-password
```

### Deployment Workflow

```bash
# Option 1: Edit kustomization.yaml directly (not recommended for production)
# Replace placeholder values before deploying

# Option 2: Use kustomize CLI
kustomize edit set secret my-app-secrets --from-literal=database-password=actual-password

# Option 3: Use overlays with patches
kubectl apply -k overlays/production/
```

### Services Using This Method

| Service | Secret Name | Location |
|---------|-------------|----------|
| Vaultwarden | `vaultwarden-secrets` | `k8s/base/vaultwarden/kustomization.yaml` |
| Authelia | `authelia-secrets` | `k8s/base/authelia/kustomization.yaml` |
| Nextcloud | `nextcloud-secrets` | `k8s/base/nextcloud/kustomization.yaml` |

## Method 2: Environment Files

### How It Works

Kustomize reads `.env` files and creates Secrets from them.

### Configuration

Create `.env` file (git-ignored):

```bash
# cloudflare-credentials.env
email=admin@example.com
apiKey=your-cloudflare-api-key
```

Reference in `kustomization.yaml`:

```yaml
secretGenerator:
  - name: cloudflare-api-credentials
    envs:
      - cloudflare-credentials.env
    options:
      disableNameSuffixHash: true
```

### Example Files

Always create `.env.example` files (tracked in git):

```bash
# cloudflare-credentials.env.example
email=your-cloudflare-email@example.com
apiKey=your-cloudflare-global-api-key
```

### Services Using This Method

| Service | Secret Name | Example File |
|---------|-------------|--------------|
| Traefik | `cloudflare-api-credentials` | `k8s/base/traefik/cloudflare-credentials.env.example` |

## Method 3: Conjur + External Secrets Operator

For production environments requiring centralized secrets management, audit logging, and automated rotation.

### Architecture

```
┌──────────────┐     ┌─────────────┐     ┌─────────────────────────┐     ┌────────────┐
│  Admin/Dev   │────▶│ Conjur OSS  │◀────│ External Secrets        │────▶│ K8s Secret │
│  (CLI)       │     │ (Vault)     │     │ Operator (ESO)          │     │            │
└──────────────┘     └─────────────┘     └─────────────────────────┘     └────────────┘
       │                    │                       │                          │
       │                    ▼                       │                          ▼
       │              ┌───────────┐                 │                    ┌───────────┐
       │              │ PostgreSQL│                 │                    │ Your App  │
       │              │ (Backend) │                 │                    │           │
       │              └───────────┘                 │                    └───────────┘
       │                                            │
       └────────────────────────────────────────────┘
                    Policy-based access
```

### Quick Start

#### Step 1: Deploy Conjur

```bash
# Create namespace and encryption key
kubectl create namespace conjur
CONJUR_DATA_KEY=$(openssl rand -base64 32)
kubectl create secret generic conjur-data-key \
  --from-literal=key=$CONJUR_DATA_KEY \
  --namespace conjur

# Deploy PostgreSQL backend
kubectl apply -f k8s/infrastructure/external-secrets/conjur-postgres.yaml
kubectl wait --for=condition=ready pod -l app=conjur-postgres -n conjur --timeout=300s

# Deploy Conjur
kubectl apply -f k8s/infrastructure/external-secrets/conjur-deploy.yaml
kubectl wait --for=condition=ready pod -l app=conjur-oss -n conjur --timeout=300s
```

#### Step 2: Initialize Conjur

```bash
# Get pod name and initialize account
CONJUR_POD=$(kubectl get pod -n conjur -l app=conjur-oss -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n conjur $CONJUR_POD -- conjurctl account create default
```

**Save the API key displayed - you'll need it later.**

#### Step 3: Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

#### Step 4: Configure SecretStore

Edit `k8s/infrastructure/external-secrets/conjur-secretstore.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: conjur-creds
  namespace: default
stringData:
  username: admin
  apikey: YOUR_API_KEY_FROM_STEP_2  # Replace this
```

Apply the configuration:

```bash
kubectl apply -f k8s/infrastructure/external-secrets/conjur-secretstore.yaml
```

#### Step 5: Load Secrets into Conjur

Install the Conjur CLI:

```bash
# macOS
brew tap cyberark/tools
brew install cyberark/tools/conjur-cli

# Linux (using Docker)
docker pull cyberark/conjur-cli:latest
alias conjur='docker run --rm -it --network host -v $HOME/.conjurrc:/root/.conjurrc cyberark/conjur-cli:latest'
```

Connect to Conjur:

```bash
# Port-forward Conjur service
kubectl port-forward -n conjur svc/conjur-oss 8080:80 &

# Initialize CLI
conjur init -u http://localhost:8080 -a default

# Login with admin
conjur login -i admin
# Enter API key when prompted
```

Create a policy file `k8s-secrets-policy.yml`:

```yaml
- !policy
  id: k8s-secrets
  body:
    # Database credentials
    - !variable database/username
    - !variable database/password
    - !variable database/host

    # API tokens
    - !variable api/github-token
    - !variable api/cloudflare-key

    # Application secrets
    - !variable vaultwarden/admin-token
    - !variable authelia/jwt-secret
    - !variable authelia/session-secret
```

Load policy and set secrets:

```bash
# Load policy structure
conjur policy load root k8s-secrets-policy.yml

# Set secret values
conjur variable set -i k8s-secrets/database/username -v "dbuser"
conjur variable set -i k8s-secrets/database/password -v "$(openssl rand -base64 32)"
conjur variable set -i k8s-secrets/vaultwarden/admin-token -v "$(openssl rand -base64 48)"
```

#### Step 6: Create ExternalSecret Resources

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: conjur
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: k8s-secrets/database/username
    - secretKey: password
      remoteRef:
        key: k8s-secrets/database/password
```

Apply and verify:

```bash
kubectl apply -f k8s/infrastructure/external-secrets/example-external-secret.yaml

# Check status
kubectl get externalsecret
kubectl get secret database-credentials -o yaml
```

### Common Conjur Operations

| Task | Command |
|------|---------|
| List all secrets | `conjur list -k variable` |
| Get secret value | `conjur variable get -i k8s-secrets/database/password` |
| Update secret | `conjur variable set -i k8s-secrets/database/password -v "new-value"` |
| Rotate secret | `conjur variable set -i k8s-secrets/database/password -v "$(openssl rand -base64 32)"` |
| Check sync status | `kubectl get externalsecret` |
| View Conjur logs | `kubectl logs -n conjur -l app=conjur-oss` |
| Access Web UI | `kubectl port-forward -n conjur svc/conjur-oss 8080:80` |

### Troubleshooting Conjur

**ExternalSecret shows "SecretSyncedError":**

```bash
# Check ESO logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# Verify SecretStore connection
kubectl get secretstore conjur -o yaml

# Test Conjur health
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://conjur-oss.conjur.svc.cluster.local/health
```

**Conjur not initializing:**

```bash
# Check Conjur logs
kubectl logs -n conjur -l app=conjur-oss

# Check PostgreSQL
kubectl logs -n conjur -l app=conjur-postgres

# Verify database
kubectl exec -n conjur -it $(kubectl get pod -n conjur -l app=conjur-postgres -o name) -- \
  psql -U postgres -c "\l"
```

## Security Best Practices

### Git Protection

Ensure `.gitignore` includes:

```gitignore
# Environment files with secrets
*.env
!*.env.example

# Kubernetes secrets
k8s/**/*.env
!k8s/**/*.env.example

# Secret files
**/secrets/
!**/secrets/.gitkeep
```

### Secret Generation

```bash
# Generate strong passwords
openssl rand -base64 32    # 43 characters
openssl rand -hex 32       # 64 characters

# Generate Argon2 hash for Authelia
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'your-password'
```

### Secret Rotation

**For Kustomize secrets:**

```bash
# Update kustomization.yaml with new value
# Redeploy
kubectl apply -k .
# Restart pods to pick up changes
kubectl rollout restart deployment/your-app
```

**For Conjur secrets:**

```bash
# Update in Conjur
conjur variable set -i k8s-secrets/database/password -v "$(openssl rand -base64 32)"

# ESO will auto-sync within refreshInterval
# Or force sync
kubectl annotate externalsecret database-credentials force-sync=$(date +%s) --overwrite

# Restart pods
kubectl rollout restart deployment/your-app
```

### Access Control

**Conjur RBAC:**

```yaml
# Create application-specific roles
- !policy
  id: apps
  body:
    - !group vaultwarden-readers
    - !permit
      role: !group vaultwarden-readers
      privileges: [read, execute]
      resource: !variable /k8s-secrets/vaultwarden/admin-token
```

## Migration Path

### From Kustomize to Conjur

1. Deploy Conjur infrastructure
2. Load existing secrets into Conjur
3. Create ExternalSecret resources
4. Update deployments to use new secret names (if changed)
5. Remove old secretGenerator entries
6. Verify application functionality

### Rollback

If Conjur is unavailable, you can quickly revert:

```bash
# Re-enable secretGenerator in kustomization.yaml
# Apply directly
kubectl apply -k .
```

## File Reference

| File | Purpose |
|------|---------|
| `k8s/infrastructure/external-secrets/README.md` | Detailed Conjur setup guide |
| `k8s/infrastructure/external-secrets/conjur-deploy.yaml` | Conjur deployment |
| `k8s/infrastructure/external-secrets/conjur-postgres.yaml` | PostgreSQL backend |
| `k8s/infrastructure/external-secrets/conjur-secretstore.yaml` | ESO SecretStore config |
| `k8s/infrastructure/external-secrets/example-external-secret.yaml` | ExternalSecret examples |

## External Resources

- [Conjur OSS Documentation](https://www.conjur.org/)
- [External Secrets Operator](https://external-secrets.io/)
- [Conjur CLI Reference](https://github.com/cyberark/conjur-cli)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/#best-practices)

---

[Back to Main README](../README.md) | [Security Guide](SECURITY.md) | [K8s Architecture](K8S_ARCHITECTURE.md)
