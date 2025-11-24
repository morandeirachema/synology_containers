# Production-Plus Overlay

## Overview

The **production-plus** overlay combines the perfect **100/100 production baseline** with **HIGH priority defense-in-depth security enhancements**.

**Grade**: 100/100 + Enhanced Security

## What's Included

### Base Production (100/100)
All components from `k8s/overlays/production/`:
- ✅ Prometheus monitoring stack
- ✅ Grafana visualization
- ✅ Loki log aggregation
- ✅ Trivy vulnerability scanning
- ✅ cert-manager for TLS
- ✅ Ingress-NGINX
- ✅ Pod Security Standards (restricted)
- ✅ NetworkPolicies
- ✅ Resource quotas and limits
- ✅ All monitoring and alerting

### HIGH Priority Security Enhancements
Additional defense-in-depth layers:

**1. Falco** - Runtime Threat Detection
- Monitor system calls via eBPF
- Detect privilege escalation, crypto mining, reverse shells
- Overhead: ~50MB RAM per node

**2. OPA Gatekeeper** - Policy Enforcement
- Custom policy enforcement beyond Pod Security Standards
- Prevent :latest tags, enforce labels, block default namespace
- Overhead: ~400MB RAM, ~100m CPU

**3. Kubescape** - Compliance Scanning
- Validate against CIS Kubernetes Benchmark
- NSA/CISA hardening guide compliance
- MITRE ATT&CK for Containers
- Overhead: ~200MB RAM (idle), scans run periodically

## Resource Requirements

### Production Baseline
- CPU: ~4 cores (existing)
- Memory: ~6.5GB (existing)
- Storage: ~50GB (existing)

### Additional Overhead (HIGH Priority)
- CPU: +0.5 cores (~12% increase)
- Memory: +650MB (~10% increase)
- Storage: Minimal (ephemeral)

### Total Production-Plus
- **CPU**: ~4.5 cores / 12 cores (37.5% utilization)
- **Memory**: ~7.2GB / 48GB (15% utilization)
- **Storage**: ~50GB

**Conclusion**: Well within cluster capacity with room to spare.

## Deployment

### Option 1: Deploy Everything (Recommended)

```bash
# Deploy production baseline + HIGH priority security
kubectl apply -k k8s/overlays/production-plus/
```

This single command deploys:
- Complete production stack (100/100)
- Falco runtime security
- Gatekeeper policy enforcement
- Kubescape compliance scanning

### Option 2: Deploy Selectively

Deploy only production baseline:
```bash
kubectl apply -k k8s/overlays/production/
```

Then add security enhancements individually:
```bash
# Add Falco only
kubectl apply -k k8s/optional/high-priority/falco/

# Add Gatekeeper only
kubectl apply -k k8s/optional/high-priority/gatekeeper/

# Add Kubescape only
kubectl apply -k k8s/optional/high-priority/kubescape/
```

### Verify Deployment

```bash
# Check all production pods
kubectl get pods -A | grep -E "(production|falco|gatekeeper|kubescape)"

# Check production-plus specific resources
kubectl get pods -n falco
kubectl get pods -n gatekeeper-system
kubectl get pods -n kubescape

# Verify security enhancements are active
kubectl get canaries -A  # Gatekeeper constraints
kubectl get cronjobs -n kubescape  # Kubescape scan schedules
kubectl logs -n falco -l app=falco --tail=10  # Falco alerts
```

## Security Posture

### Without Production-Plus (100/100 Baseline)

```
┌─────────────────────────────────────┐
│  Pre-deployment Security            │
│  - Trivy image scanning             │
│  - Admission control (PSS)          │
└─────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│  Runtime Security                   │
│  - Pod Security Standards           │
│  - NetworkPolicies                  │
│  - Resource limits                  │
└─────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│  Monitoring & Response              │
│  - Prometheus alerts                │
│  - Grafana dashboards               │
│  - Manual investigation             │
└─────────────────────────────────────┘
```

### With Production-Plus (100/100 + Defense-in-Depth)

```
┌─────────────────────────────────────┐
│  Pre-deployment Security            │
│  - Trivy image scanning             │
│  - Gatekeeper admission policies    │ ← ENHANCED
│  - PSS enforcement                  │
└─────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│  Runtime Security                   │
│  - Pod Security Standards           │
│  - Falco threat detection           │ ← NEW
│  - NetworkPolicies                  │
│  - Gatekeeper policy enforcement    │ ← NEW
└─────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│  Compliance & Audit                 │
│  - Kubescape CIS/NSA scans          │ ← NEW
│  - Audit reports                    │ ← NEW
│  - Compliance dashboards            │ ← NEW
└─────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│  Monitoring & Response              │
│  - Prometheus alerts                │
│  - Grafana dashboards               │
│  - Falco real-time alerts           │ ← NEW
│  - Automated threat response        │ ← NEW
└─────────────────────────────────────┘
```

## Defense-in-Depth Layers

### Layer 1: Admission Control
**Baseline (100/100)**:
- Pod Security Standards: Restrict privileged pods, capabilities, host access

**Production-Plus**:
- Gatekeeper: Custom policies (no :latest tags, required labels, resource limits)
- Validation: Block non-compliant resources at admission time

### Layer 2: Runtime Security
**Baseline (100/100)**:
- NetworkPolicies: Restrict pod-to-pod communication
- ResourceQuotas: Prevent resource exhaustion

**Production-Plus**:
- Falco: Detect anomalous syscalls, privilege escalation, file access
- Real-time alerts: Instant notification of suspicious activity

### Layer 3: Compliance & Audit
**Baseline (100/100)**:
- Manual audits
- Prometheus metrics

**Production-Plus**:
- Kubescape: Automated CIS benchmark scanning (daily)
- Compliance reports: Detailed findings with remediation guidance
- Trend analysis: Track security posture over time

## Use Cases

### Homelab Production Workloads
**Scenario**: Running production services (websites, databases, APIs)

**Recommendation**: **Use production-plus**
- Falco detects if containers are compromised
- Gatekeeper prevents misconfigurations
- Kubescape validates best practices

### Learning & Experimentation
**Scenario**: Testing new software, breaking things

**Recommendation**: Use production baseline
- 100/100 security is sufficient
- Avoid false positives from experimental workloads
- Add Chaos Mesh instead (low-priority)

### Maximum Security Hardening
**Scenario**: Handling sensitive data or compliance requirements

**Recommendation**: **Production-plus + MEDIUM priority**
- All HIGH priority (Falco, Gatekeeper, Kubescape)
- CloudNativePG for database security
- OpenCost for resource accountability

### Resource-Constrained Clusters
**Scenario**: Small cluster (2 nodes, 16GB RAM each = 32GB total)

**Recommendation**: Production baseline + Falco only
- Falco provides highest value (~50MB)
- Skip Gatekeeper and Kubescape (higher overhead)

## Monitoring Integration

All security enhancements integrate with existing Prometheus/Grafana:

### Grafana Dashboards
```bash
# Falco runtime alerts
Dashboard ID: 11914

# Gatekeeper policy violations
Dashboard ID: 14333

# Kubescape compliance scores
Dashboard ID: Custom (metrics exposed)
```

### Prometheus Alerts
**Existing (100/100)**:
- 50+ alerts for infrastructure health
- Resource saturation warnings
- Pod/deployment failures

**New (Production-Plus)**:
- Falco: 8 new runtime security alerts
- Gatekeeper: 5 new policy violation alerts
- Kubescape: 5 new compliance alerts

**Total**: ~68 alerts covering all aspects

### Alert Routing
All alerts route to existing AlertManager:
- Critical → Immediate notification
- Warning → Aggregated digest
- Info → Logged for audit

## Upgrading from Production

### Step 1: Backup Current State
```bash
# Export current production resources
kubectl get all -n production -o yaml > production-backup.yaml
```

### Step 2: Apply Production-Plus
```bash
# Deploy production-plus (includes production baseline)
kubectl apply -k k8s/overlays/production-plus/
```

### Step 3: Verify Security Enhancements
```bash
# Check Falco is detecting events
kubectl logs -n falco -l app=falco --tail=50

# Check Gatekeeper constraints are active
kubectl get constraints

# Check Kubescape scan schedules
kubectl get cronjobs -n kubescape
```

### Step 4: Review Alerts
```bash
# Check for any new violations
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -20

# Review Gatekeeper violations
kubectl get constraints -o json | jq '.items[] | select(.status.totalViolations > 0)'
```

## Rollback

If needed, rollback to baseline:

```bash
# Remove security enhancements
kubectl delete -k k8s/optional/high-priority/falco/
kubectl delete -k k8s/optional/high-priority/gatekeeper/
kubectl delete -k k8s/optional/high-priority/kubescape/

# Production baseline remains intact
```

**Your 100/100 perfect score is preserved.**

## Cost Analysis

### Baseline Production (100/100)
- Electricity: ~200W × 24h × $0.12/kWh = $0.58/day
- Total: ~$17.50/month

### Production-Plus (100/100 + Security)
- Additional overhead: ~10% increase
- Electricity: ~220W × 24h × $0.12/kWh = $0.63/day
- Total: ~$19/month

**Cost increase**: ~$1.50/month (8.5% increase)

**Value**: Enterprise-grade security features (worth $500-1000/month in cloud)

## Comparison

| Feature | Production (100/100) | Production-Plus |
|---------|---------------------|-----------------|
| **Cluster Score** | 100/100 | 100/100 |
| **Security Layers** | 2 (PSS, NetworkPolicy) | 5 (PSS, NP, Falco, Gatekeeper, Kubescape) |
| **Runtime Threat Detection** | ❌ No | ✅ Falco |
| **Custom Policies** | ❌ No | ✅ Gatekeeper |
| **Compliance Scanning** | ❌ Manual | ✅ Automated (Kubescape) |
| **Overhead** | 0% (baseline) | +10% RAM, +12% CPU |
| **Cost** | $17.50/month | $19/month |
| **Suitable For** | Homelab workloads | Production workloads |

## When to Use Each

**Use Production (100/100)** when:
- ✅ Learning Kubernetes
- ✅ Testing applications
- ✅ Resource-constrained clusters
- ✅ Non-critical workloads

**Use Production-Plus** when:
- ✅ Running production services
- ✅ Handling sensitive data
- ✅ Need compliance reporting
- ✅ Want defense-in-depth security
- ✅ Learning enterprise security practices

## Learn More

See individual component documentation:
- [Falco](../../optional/high-priority/falco/README.md) - Runtime security
- [Gatekeeper](../../optional/high-priority/gatekeeper/README.md) - Policy enforcement
- [Kubescape](../../optional/high-priority/kubescape/README.md) - Compliance scanning

---

**Remember**: Production-Plus is **optional**. Your cluster is **already perfect** at 100/100 with the baseline production overlay.
