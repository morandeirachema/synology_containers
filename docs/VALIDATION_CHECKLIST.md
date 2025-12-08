# Kubernetes Validation Checklist

Production readiness validation for the Talos Kubernetes cluster.

**Last Updated**: 2025-12-09

---

## Score Categories

| Category | Points | Description |
|----------|--------|-------------|
| Security | 40 | PSS, NetworkPolicies, container hardening, secrets, RBAC, TLS |
| High Availability | 20 | Replicas, PDBs, anti-affinity, health checks, HPA |
| Observability | 15 | Metrics, alerts, logging, tracing, dashboards |
| Resource Management | 10 | ResourceQuotas, LimitRanges, QoS classes |
| Resilience | 10 | Update strategy, backups, DR testing, storage |
| GitOps | 5 | Kustomize, ArgoCD, IaC, automation |

---

## Security (40 points)

### Pod Security Standards (5 pts)

```bash
# Verify PSS labels on namespaces
kubectl get ns -L pod-security.kubernetes.io/enforce

# Expected: restricted for production, baseline for infrastructure
```

**Files**: `k8s/base/security/namespaces.yaml`

### Network Security (10 pts)

```bash
# Count NetworkPolicies
kubectl get networkpolicies -A | wc -l

# Verify default deny exists
kubectl get networkpolicies -A | grep default-deny

# Test network isolation
kubectl run test -n tools --rm -it --image=busybox -- \
  wget -qO- http://vaultwarden.vaultwarden.svc.cluster.local --timeout=3
# Should timeout (blocked)
```

**Files**: `k8s/base/security/networkpolicies.yaml`

### Container Security (8 pts)

```bash
# Verify non-root containers
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.securityContext.runAsNonRoot != true) | .metadata.name'

# Verify seccompProfile
kubectl get pods -A -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.spec.securityContext.seccompProfile.type)"'

# Verify capabilities dropped
kubectl get pods -A -o json | \
  jq '.items[].spec.containers[].securityContext.capabilities.drop'
```

**Requirements**:
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`
- `seccompProfile.type: RuntimeDefault`

### Container Image Scanning (5 pts)

```bash
# Verify Trivy Operator
kubectl get pods -n trivy-system

# Check vulnerability reports
kubectl get vulnerabilityreports -A | head -20

# Verify scan schedules
kubectl get cronjobs -n trivy-system
```

**Files**: `k8s/infrastructure/security/trivy/`

### Secrets Management (5 pts)

```bash
# Verify no plaintext secrets in Git
grep -r "password:" k8s/ | grep -v secretGenerator | grep -v "# password"

# Verify Conjur
kubectl get pods -n conjur

# Verify External Secrets
kubectl get externalsecrets -A
```

**Files**: `k8s/infrastructure/external-secrets/`

### RBAC (4 pts)

```bash
# Check for overly permissive bindings
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name == "cluster-admin") | .metadata.name'

# Verify service accounts exist
kubectl get sa -A | grep -E "(traefik|authelia|vaultwarden|nextcloud)"
```

### TLS/Certificates (3 pts)

```bash
# Verify cert-manager
kubectl get pods -n cert-manager

# Check certificate status
kubectl get certificates -A

# Check expiration dates
kubectl get certificates -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.notAfter)"'
```

---

## High Availability (20 points)

### Replica Management (4 pts)

```bash
# Verify replica counts
kubectl get deployments -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.spec.replicas)"'

# Critical services should have 2+ replicas
```

### PodDisruptionBudgets (4 pts)

```bash
# Verify PDBs exist
kubectl get pdb -A

# Expected:
# traefik: minAvailable: 2
# authelia: minAvailable: 1
# databases: maxUnavailable: 0
```

**Files**: `k8s/base/*/pdb.yaml`

### Pod Scheduling (3 pts)

```bash
# Verify pod distribution across nodes
kubectl get pods -A -o wide | awk '{print $1, $2, $8}' | sort -k3

# Check anti-affinity rules
kubectl get deploy traefik -n traefik -o yaml | grep -A10 affinity
```

### Health Checks (3 pts)

```bash
# Verify pods have health checks
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].livenessProbe == null) | .metadata.name'

# Check probe configuration
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Liveness\|Readiness"
```

### Resource Management (3 pts)

```bash
# Verify resource requests exist
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[] | select(.resources.requests == null) | .name'

# Check QoS classes
kubectl get pods -A -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.qosClass)"'
```

### Auto-Scaling (3 pts)

```bash
# Verify HPAs
kubectl get hpa -A

# Expected:
# traefik: 2-10 replicas, 50% CPU
# authelia: 2-5 replicas, 70% CPU
```

**Files**: `k8s/base/*/hpa.yaml`

---

## Observability (15 points)

### Metrics Collection (4 pts)

```bash
# Verify Prometheus
kubectl get pods -n monitoring | grep prometheus

# Count ServiceMonitors
kubectl get servicemonitors -A | wc -l

# Access Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Open http://localhost:9090/targets
```

### Alerting (4 pts)

```bash
# Count alerts
kubectl get prometheusrules -A -o json | \
  jq '[.items[].spec.groups[].rules[]] | length'

# Access Alertmanager
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```

### Logging (3 pts)

```bash
# Verify Loki
kubectl get pods -n logging | grep loki

# Verify Promtail
kubectl get daemonset -n logging promtail

# Access via Grafana Explore
```

### Distributed Tracing (3 pts)

```bash
# Verify Jaeger
kubectl get pods -n tracing

# Access Jaeger UI
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
```

**Files**: `k8s/infrastructure/jaeger/`

### Dashboards (1 pt)

```bash
# Verify Grafana
kubectl get pods -n monitoring | grep grafana

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
```

---

## Resource Management (10 points)

### ResourceQuotas (5 pts)

```bash
# Verify ResourceQuotas
kubectl get resourcequota -A

# Check usage vs quota
kubectl describe resourcequota -n production
```

**Files**: `k8s/base/security/resourcequotas.yaml`

### LimitRanges (3 pts)

```bash
# Verify LimitRanges
kubectl get limitrange -A

# Check default values
kubectl describe limitrange -n production
```

### QoS Classes (2 pts)

```bash
# Check QoS distribution
kubectl get pods -A -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.qosClass)"' | \
  sort -k2

# Guaranteed: Traefik, Authelia, Databases
# Burstable: Applications
# BestEffort: None (should be empty)
```

---

## Resilience (10 points)

### Update Strategy (2 pts)

```bash
# Verify RollingUpdate strategy
kubectl get deployments -A -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.spec.strategy.type)"'

# All should be "RollingUpdate"

# Check maxSurge/maxUnavailable
kubectl get deploy traefik -n traefik -o json | \
  jq '.spec.strategy.rollingUpdate'
```

### Backup Strategy (4 pts)

```bash
# Verify Velero
kubectl get pods -n velero

# Check backup schedules
kubectl get schedules -n velero

# List recent backups
velero backup get

# Check backup status
velero backup describe <backup-name>
```

**Files**: `k8s/infrastructure/velero/`

### Disaster Recovery (3 pts)

```bash
# Verify DR testing CronJob
kubectl get cronjobs -n velero

# Check last DR test
kubectl logs -n velero -l job-name=quarterly-dr-test --tail=100

# Test restore (dry-run)
velero restore create --from-backup <backup-name> --dry-run
```

### Storage (1 pt)

```bash
# Check storage classes
kubectl get storageclass

# Verify PVs and PVCs
kubectl get pv,pvc -A

# Check NFS provisioner
kubectl get pods -n nfs-provisioner
```

---

## GitOps and Automation (5 points)

### Kustomize (2 pts)

```bash
# Verify structure
ls -la k8s/base/
ls -la k8s/overlays/

# Test build
kubectl kustomize k8s/overlays/production/ | head -50
```

### ArgoCD (2 pts)

```bash
# Verify ArgoCD
kubectl get pods -n argocd

# List applications
kubectl get applications -n argocd

# Check sync status
argocd app list
```

### Automated Updates (1 pt)

```bash
# Verify Renovate configuration
cat .github/renovate.json

# Check recent Renovate PRs
gh pr list --label renovate
```

---

## Quick Validation Script

```bash
#!/bin/bash
echo "=== Kubernetes Validation ==="
echo ""

echo "Nodes:"
kubectl get nodes -o wide
echo ""

echo "Non-running pods:"
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""

echo "PDBs:"
kubectl get pdb -A
echo ""

echo "HPAs:"
kubectl get hpa -A
echo ""

echo "NetworkPolicies:"
kubectl get networkpolicies -A | wc -l
echo ""

echo "ResourceQuotas:"
kubectl get resourcequota -A
echo ""

echo "Backup schedules:"
kubectl get schedules -n velero 2>/dev/null || echo "Velero not installed"
echo ""

echo "Certificates:"
kubectl get certificates -A
echo ""

echo "=== Validation Complete ==="
```

Save as `scripts/k8s-validate.sh` and run for quick checks.

---

## Troubleshooting

### Pod Issues

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

### Storage Issues

```bash
kubectl describe pvc <pvc-name> -n <namespace>
kubectl get pv
```

### Network Issues

```bash
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash
```

### DNS Issues

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 -- nslookup kubernetes
```

---

[Back to Main README](../README.md) | [Operations Guide](K8S_OPERATIONS.md) | [Architecture](K8S_ARCHITECTURE.md)
