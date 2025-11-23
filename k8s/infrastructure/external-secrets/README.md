# Conjur Secrets Management

This directory contains the configuration for **CyberArk Conjur OSS** and **External Secrets Operator** for enterprise-grade secrets management in Kubernetes.

## Quick Start

### 1. Deploy Conjur

```bash
# Create namespace
kubectl create namespace conjur

# Generate and create data key secret
CONJUR_DATA_KEY=$(openssl rand -base64 32)
kubectl create secret generic conjur-data-key \
  --from-literal=key=$CONJUR_DATA_KEY \
  --namespace conjur

# Deploy PostgreSQL
kubectl apply -f conjur-postgres.yaml

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=conjur-postgres -n conjur --timeout=300s

# Deploy Conjur
kubectl apply -f conjur-deploy.yaml

# Wait for Conjur to be ready
kubectl wait --for=condition=ready pod -l app=conjur-oss -n conjur --timeout=300s
```

### 2. Initialize Conjur

```bash
# Get Conjur pod name
CONJUR_POD=$(kubectl get pod -n conjur -l app=conjur-oss -o jsonpath='{.items[0].metadata.name}')

# Initialize Conjur account (save the API key!)
kubectl exec -n conjur $CONJUR_POD -- conjurctl account create default
```

**IMPORTANT**: Save the API key displayed. You'll need it for the SecretStore configuration!

### 3. Install External Secrets Operator

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install ESO
helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

### 4. Configure SecretStore

Edit `conjur-secretstore.yaml` and replace `REPLACE_WITH_CONJUR_API_KEY` with the API key from step 2.

```bash
# Apply SecretStore
kubectl apply -f conjur-secretstore.yaml
```

### 5. Load Secrets into Conjur

**Install Conjur CLI:**

```bash
# macOS
brew tap cyberark/tools
brew install cyberark/tools/conjur-cli

# Linux (using Docker)
docker pull cyberark/conjur-cli:latest
alias conjur='docker run --rm -it --network host -v $HOME/.conjurrc:/root/.conjurrc cyberark/conjur-cli:latest'
```

**Initialize and login:**

```bash
# Port-forward Conjur service
kubectl port-forward -n conjur svc/conjur-oss 8080:80 &

# Initialize Conjur CLI
conjur init -u http://localhost:8080 -a default

# Login with admin and the API key from step 2
conjur login -i admin
```

**Load policies and secrets:**

Create `k8s-secrets-policy.yml`:

```yaml
- !policy
  id: k8s-secrets
  body:
    # Database secrets
    - !variable database/username
    - !variable database/password
    - !variable database/host
    - !variable database/port

    # API tokens
    - !variable api/github-token
    - !variable api/docker-registry-token

    # PostgreSQL connection
    - !variable postgres/username
    - !variable postgres/password
    - !variable postgres/host
    - !variable postgres/port
    - !variable postgres/database

    # TLS certificates
    - !variable tls/certificate
    - !variable tls/private-key
```

Load policy and set secrets:

```bash
# Load the policy
conjur policy load root k8s-secrets-policy.yml

# Set database secrets
conjur variable set -i k8s-secrets/database/username -v "dbuser"
conjur variable set -i k8s-secrets/database/password -v "super-secret-password"
conjur variable set -i k8s-secrets/database/host -v "postgres.default.svc.cluster.local"
conjur variable set -i k8s-secrets/database/port -v "5432"

# Set API tokens
conjur variable set -i k8s-secrets/api/github-token -v "ghp_your_token_here"
conjur variable set -i k8s-secrets/api/docker-registry-token -v "registry_token_here"

# Set PostgreSQL connection details
conjur variable set -i k8s-secrets/postgres/username -v "postgres"
conjur variable set -i k8s-secrets/postgres/password -v "postgres-password"
conjur variable set -i k8s-secrets/postgres/host -v "conjur-postgres.conjur.svc.cluster.local"
conjur variable set -i k8s-secrets/postgres/port -v "5432"
conjur variable set -i k8s-secrets/postgres/database -v "myapp"
```

### 6. Create ExternalSecrets

```bash
# Apply example ExternalSecrets
kubectl apply -f example-external-secret.yaml

# Check if secrets were created
kubectl get externalsecrets
kubectl get secrets | grep -E 'database-credentials|api-tokens|postgres-connection'
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│            Secrets Management Flow               │
├─────────────────────────────────────────────────┤
│                                                  │
│  1. Developer/Admin                              │
│     ↓ (conjur CLI)                               │
│  2. Conjur OSS                                   │
│     • Stores encrypted secrets                  │
│     • PostgreSQL backend                        │
│     • Policy-based access control               │
│     ↓                                            │
│  3. External Secrets Operator                    │
│     • Polls Conjur every interval               │
│     • Reads secrets based on policy             │
│     ↓                                            │
│  4. Kubernetes Secrets                           │
│     • Standard K8s secrets created              │
│     • Auto-updated when changed in Conjur       │
│     ↓                                            │
│  5. Applications                                 │
│     • Mount secrets as env vars or files        │
│     • No direct access to Conjur                │
│                                                  │
└─────────────────────────────────────────────────┘
```

## File Descriptions

| File | Description |
|------|-------------|
| `conjur-postgres.yaml` | PostgreSQL StatefulSet for Conjur backend |
| `conjur-deploy.yaml` | Conjur OSS Deployment, Service, and Ingress |
| `conjur-secretstore.yaml` | SecretStore and ClusterSecretStore for ESO |
| `example-external-secret.yaml` | Example ExternalSecret resources |
| `README.md` | This file |

## Common Operations

### View Conjur Logs

```bash
kubectl logs -n conjur -l app=conjur-oss -f
```

### Access Conjur Web UI

```bash
# Port-forward
kubectl port-forward -n conjur svc/conjur-oss 8080:80

# Open browser to http://localhost:8080
```

### List all secrets in Conjur

```bash
conjur list -k variable
```

### Get a secret value

```bash
conjur variable get -i k8s-secrets/database/password
```

### Update a secret

```bash
conjur variable set -i k8s-secrets/database/password -v "new-password"

# ExternalSecret will auto-update within refreshInterval
```

### Rotate secrets

```bash
# Update in Conjur
conjur variable set -i k8s-secrets/database/password -v "$(openssl rand -base64 32)"

# Restart pods to pick up new secret
kubectl rollout restart deployment/your-app
```

### Check ExternalSecret status

```bash
kubectl describe externalsecret database-credentials
kubectl get externalsecret database-credentials -o yaml
```

### Troubleshooting

**ExternalSecret shows "SecretSyncedError":**

```bash
# Check ESO logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# Verify SecretStore
kubectl get secretstore conjur -o yaml

# Test Conjur connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://conjur-oss.conjur.svc.cluster.local/health
```

**Conjur not initializing:**

```bash
# Check Conjur logs
kubectl logs -n conjur -l app=conjur-oss

# Check PostgreSQL
kubectl logs -n conjur -l app=conjur-postgres

# Verify database connection
kubectl exec -n conjur -it $(kubectl get pod -n conjur -l app=conjur-postgres -o name) -- \
  psql -U postgres -c "\l"
```

## Security Best Practices

1. **Rotate API Keys**: Periodically rotate Conjur admin API key
2. **Use RBAC**: Create separate Conjur identities/roles per application
3. **Audit Logs**: Regularly review Conjur audit logs
4. **Network Policies**: Restrict access to Conjur service
5. **Backup**: Regularly backup Conjur PostgreSQL database
6. **Never Commit Secrets**: Don't commit API keys or secrets to Git
7. **Use Namespaces**: Isolate SecretStores per namespace where possible

## Resources

- **Conjur OSS Documentation**: https://www.conjur.org/
- **External Secrets Operator**: https://external-secrets.io/
- **Conjur CLI**: https://github.com/cyberark/conjur-cli
- **CyberArk Conjur**: https://www.cyberark.com/products/privileged-account-security-solution/conjur/

---

[Back to Setup Guide](../../../docs/TALOS_KUBERNETES_SETUP.md) | [Back to Architecture](../../../docs/K8S_ARCHITECTURE.md)
