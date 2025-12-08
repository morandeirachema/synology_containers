# Kubescape - Compliance & Security Scanning

## Overview

Kubescape is an open-source Kubernetes security platform that scans clusters against multiple compliance frameworks including **CIS Kubernetes Benchmark**, **NSA/CISA Hardening Guide**, and **MITRE ATT&CK**.

**Status**: ✅ OPTIONAL - Your cluster is already 100/100 without this

## Why Kubescape?

### Complements Existing Security

Your 100/100 cluster already has:
- ✅ **Trivy**: Container vulnerability scanning
- ✅ **Pod Security Standards**: Runtime security policies
- ✅ **NetworkPolicies**: Network security

Kubescape adds:
- 🎯 **Compliance validation**: Against industry standards (CIS, NSA, CISA)
- 🎯 **Configuration auditing**: Identifies insecure configurations
- 🎯 **Risk scoring**: Quantifies security posture
- 🎯 **Remediation guidance**: Actionable fix recommendations

### Defense-in-Depth

```
┌─────────────────────────────────────┐
│  Trivy (100/100)                    │  Image scanning (CVEs)
├─────────────────────────────────────┤
│  Pod Security Standards (100/100)   │  Pod-level security
├─────────────────────────────────────┤
│  Falco (OPTIONAL)                   │  Runtime threat detection
├─────────────────────────────────────┤
│  Gatekeeper (OPTIONAL)              │  Custom policy enforcement
├─────────────────────────────────────┤
│  Kubescape (OPTIONAL)               │  Compliance validation
└─────────────────────────────────────┘
```

## What Kubescape Scans

### 1. **CIS Kubernetes Benchmark** (Daily)
```
- Control plane configuration
- Worker node configuration
- RBAC and service accounts
- Pod security policies
- Network policies
- Secrets management
- Audit logging
```

**Score**: 0-100% compliance with CIS recommendations

### 2. **NSA/CISA Hardening Guide** (Weekly)
```
- Non-root containers
- Immutable root filesystems
- Resource limits
- Network segmentation
- Admission controllers
- Supply chain security
```

**Frameworks**: NSA/CISA Kubernetes Hardening Guidance

### 3. **MITRE ATT&CK** (Monthly)
```
- Initial access vectors
- Execution techniques
- Persistence mechanisms
- Privilege escalation paths
- Defense evasion
- Discovery techniques
```

**Coverage**: MITRE ATT&CK for Containers

## Architecture

```
┌──────────────────────────────────────────────────┐
│         Kubescape Deployment (1 replica)         │
│  - Main scanner service                          │
│  - Stores scan configurations                    │
│  - Exposes metrics                               │
└──────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ↓            ↓            ↓
┌──────────────┐ ┌─────────┐ ┌──────────────┐
│ CIS Scan     │ │ NSA     │ │ MITRE Scan   │
│ (Daily 2AM)  │ │ (Weekly)│ │ (Monthly)    │
│ CronJob      │ │ CronJob │ │ CronJob      │
└──────────────┘ └─────────┘ └──────────────┘
          │            │            │
          └────────────┼────────────┘
                       ↓
            ┌──────────────────────┐
            │  Kubernetes API      │
            │  - Read all resources│
            │  - Read RBAC         │
            │  - Read configs      │
            └──────────────────────┘
                       │
                       ↓
            ┌──────────────────────┐
            │  Scan Results        │
            │  - JSON reports      │
            │  - ConfigMap storage │
            │  - Prometheus metrics│
            └──────────────────────┘
                       │
          ┌────────────┼────────────┐
          ↓            ↓            ↓
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │Prometheus│  │  Grafana │  │   Logs   │
   │ (Metrics)│  │(Dashboard│  │  (Loki)  │
   └──────────┘  └──────────┘  └──────────┘
```

## Resource Requirements

### Main Deployment (1 replica)
- **CPU**: 100m request, 500m limit
- **Memory**: 200Mi request, 500Mi limit
- **Storage**: None (ephemeral)

### Scan Jobs (during scan execution)
- **CPU**: 200m request, 1000m limit per job
- **Memory**: 256Mi request, 1Gi limit per job
- **Duration**: 5-15 minutes per scan

### Total Overhead
- **Idle**: ~200m CPU, ~500Mi memory
- **During scan**: ~1.2 CPU, ~1.5Gi memory (temporary)

**Conclusion**: Low overhead - scans run periodically, not continuously.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for metrics)
- Grafana (for visualization)
- kubectl access (for ConfigMap updates)

### Quick Deploy

```bash
kubectl apply -k k8s/optional/high-priority/kubescape/
```

### Verify Deployment

```bash
# Check deployment
kubectl get deployment -n kubescape
kubectl get pods -n kubescape

# Check scan schedules
kubectl get cronjobs -n kubescape

# Expected output:
# NAME                    SCHEDULE      SUSPEND   ACTIVE
# kubescape-scan-cis      0 2 * * *     False     0        (Daily at 2 AM)
# kubescape-scan-nsa      0 3 * * 0     False     0        (Weekly Sunday 3 AM)
# kubescape-scan-mitre    0 4 1 * *     False     0        (Monthly 1st day 4 AM)
```

## Configuration

### Scan Frameworks

Kubescape supports multiple frameworks:

| Framework | Schedule | Description |
|-----------|----------|-------------|
| **CIS** | Daily 2AM | CIS Kubernetes Benchmark v1.23 |
| **NSA** | Weekly Sun 3AM | NSA/CISA Hardening Guide |
| **MITRE** | Monthly 1st 4AM | MITRE ATT&CK for Containers |

### Adjust Scan Schedule

Edit the CronJob schedules in `scan-schedules.yaml`:

```yaml
spec:
  schedule: "0 6 * * *"  # Change to 6 AM daily
```

Apply changes:
```bash
kubectl apply -k k8s/optional/high-priority/kubescape/
```

### Run Manual Scan

```bash
# Run CIS scan now
kubectl create job manual-cis-scan \
  --from=cronjob/kubescape-scan-cis \
  -n kubescape

# Watch progress
kubectl logs -n kubescape -l job-name=manual-cis-scan -f
```

## Viewing Results

### 1. View Latest Scan Logs

```bash
# Get latest CIS scan logs
kubectl logs -n kubescape -l scan-type=cis-benchmark --tail=100

# Get latest NSA scan logs
kubectl logs -n kubescape -l scan-type=nsa-cisa --tail=100
```

### 2. View Scan Results in ConfigMap

```bash
# Get latest CIS results
kubectl get configmap scan-results -n kubescape -o jsonpath='{.data.latest-cis-scan\.json}' | jq .

# Extract summary
kubectl get configmap scan-results -n kubescape -o jsonpath='{.data.latest-cis-scan\.json}' | jq '.summaryDetails'
```

### 3. Check Compliance Score

```bash
# Parse CIS compliance score
kubectl get configmap scan-results -n kubescape -o jsonpath='{.data.latest-cis-scan\.json}' | \
  jq '.summaryDetails.score'

# Output example: 87.5 (87.5% CIS compliant)
```

### 4. View Failed Controls

```bash
# List failed CIS controls
kubectl get configmap scan-results -n kubescape -o jsonpath='{.data.latest-cis-scan\.json}' | \
  jq '.results[] | select(.status == "failed") | {control: .controlID, name: .controlName, severity: .severity}'
```

## Understanding Scan Results

### Compliance Score

```
100% - Perfect compliance (all controls passed)
90-99% - Excellent (minor issues)
80-89% - Good (some remediation needed)
70-79% - Fair (significant gaps)
<70% - Poor (urgent remediation required)
```

**Your 100/100 cluster likely scores 85-95% on CIS** (already very secure).

### Severity Levels

- **Critical**: Immediate security risk
- **High**: Significant security concern
- **Medium**: Security improvement recommended
- **Low**: Best practice suggestion

### Common Findings

Even secure clusters may have findings due to architectural choices:

| Finding | Why It Happens | Action |
|---------|----------------|--------|
| "No PodSecurityPolicy" | PSP is deprecated, you use Pod Security Standards | Ignore (PSS is better) |
| "etcd not encrypted" | Talos uses different encryption | Verify Talos encryption |
| "kubelet anonymous auth" | Talos default configuration | Check if acceptable for your threat model |

**Don't chase 100% blindly** - understand each finding's context.

## Monitoring & Alerts

### Prometheus Metrics

Kubescape exposes metrics at `:8000/metrics`:

```
kubescape_cluster_compliance_score - Overall compliance score
kubescape_framework_compliance_score{framework="cis"} - CIS score
kubescape_control_status{control="...",status="passed|failed"} - Per-control status
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `KubescapeDown` | Warning | Scanner pod down >10 min |
| `KubescapeCISScanFailed` | Warning | Daily CIS scan failed |
| `KubescapeNSAScanFailed` | Warning | Weekly NSA scan failed |
| `KubescapeCISScanNotRun` | Warning | No scan in 2 days |
| `KubescapeScanRunningTooLong` | Warning | Scan running >1 hour |

### Grafana Dashboard

Create a custom dashboard with panels:

1. **Compliance Score Over Time** (line graph)
```
kubescape_framework_compliance_score{framework="cis"}
```

2. **Failed Controls by Severity** (bar chart)
```
count by (severity) (kubescape_control_status{status="failed"})
```

3. **Scan Success Rate** (gauge)
```
rate(kube_job_status_succeeded{job_name=~"kubescape-scan.*"}[7d])
```

## Remediation

### Example: Fix Failed CIS Control

**Finding**: "Container running as root"

**Remediation**:
```yaml
# In your deployment
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
```

**Finding**: "No resource limits"

**Remediation**:
```yaml
# In your container spec
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Finding**: "Missing NetworkPolicy"

**Remediation**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Re-scan After Fixes

```bash
# Run manual scan to validate fixes
kubectl create job validate-fixes \
  --from=cronjob/kubescape-scan-cis \
  -n kubescape

# Check new score
kubectl logs -n kubescape -l job-name=validate-fixes -f | grep "Risk score"
```

## Integration with Existing Stack

### With Trivy

| Tool | Focus | Coverage |
|------|-------|----------|
| **Trivy** | Container images | CVEs, misconfigurations in images |
| **Kubescape** | Cluster configuration | CIS, NSA, CISA compliance |

**Both are complementary** - Trivy scans images, Kubescape scans cluster.

### With Gatekeeper

Kubescape findings can inform Gatekeeper policies:

1. Kubescape finds: "Containers running as root"
2. Create Gatekeeper constraint to enforce `runAsNonRoot: true`
3. Prevents future violations

### With Falco

| Tool | Detection Method | When |
|------|------------------|------|
| **Kubescape** | Static analysis | Pre-deployment, periodic scans |
| **Falco** | Runtime monitoring | During execution |

**Both are complementary** - Kubescape audits config, Falco detects runtime threats.

## Troubleshooting

### Scan Jobs Failing

```bash
# Check job status
kubectl get jobs -n kubescape

# View failure reason
kubectl describe job kubescape-scan-cis-XXXXX -n kubescape

# Check logs
kubectl logs -n kubescape -l job-name=kubescape-scan-cis-XXXXX
```

**Common issues**:
- Insufficient RBAC: Verify ClusterRole permissions
- Memory limits: Increase to 1Gi if scanning large cluster
- Timeout: Scans usually take 5-15 minutes

### No Results in ConfigMap

```bash
# Check if scan completed successfully
kubectl get jobs -n kubescape

# Manually update ConfigMap (scan job should do this)
kubectl create configmap scan-results \
  --from-literal=latest-scan.json="{}" \
  -n kubescape \
  --dry-run=client -o yaml | kubectl apply -f -
```

### High Memory Usage During Scan

This is expected - scans are resource-intensive. Memory usage will drop after scan completes.

To reduce:
```yaml
# Scan specific namespaces only
args:
  - --include-namespaces=production,security
```

## Security Considerations

### RBAC Permissions

Kubescape ServiceAccount has cluster-wide **read-only** access:

```yaml
verbs: ["get", "list"]  # Read-only
```

**Why**: Needs to read all resources to validate configuration.

**Mitigation**:
- No write permissions
- Well-audited open-source tool (CNCF sandbox)
- Limited to kubescape namespace

### Scan Results Storage

Scan results stored in ConfigMaps may contain sensitive information about your cluster configuration.

**Recommendation**:
- Limit access to `kubescape` namespace
- Use RBAC to restrict who can read ConfigMaps
- Consider encrypting scan results

```bash
# Restrict ConfigMap access
kubectl create role scan-results-reader \
  --verb=get \
  --resource=configmaps \
  --resource-name=scan-results \
  -n kubescape
```

## Frameworks Explained

### CIS Kubernetes Benchmark

**Publisher**: Center for Internet Security
**Scope**: Industry-standard Kubernetes security configuration
**Controls**: ~200 checks across 5 sections

**Sections**:
1. Control Plane Components (API server, scheduler, controller)
2. etcd Configuration
3. Control Plane Configuration
4. Worker Nodes
5. Policies (RBAC, Pod Security, Network)

### NSA/CISA Hardening Guide

**Publisher**: US National Security Agency / Cybersecurity Infrastructure Security Agency
**Scope**: Kubernetes hardening for high-security environments
**Controls**: ~50 critical recommendations

**Focus Areas**:
- Pod security (non-root, read-only, capabilities)
- Network policies
- Authentication & authorization
- Audit logging
- Supply chain security

### MITRE ATT&CK for Containers

**Publisher**: MITRE Corporation
**Scope**: Adversary tactics and techniques for container environments
**Controls**: Maps Kubernetes misconfigurations to attack techniques

**Tactics**:
- Initial Access, Execution, Persistence
- Privilege Escalation, Defense Evasion
- Credential Access, Discovery
- Lateral Movement, Impact

## Comparison: Kubescape vs Manual Audit

| Task | Manual Audit | Kubescape |
|------|--------------|-----------|
| **Check 200+ CIS controls** | ~8 hours | 5 minutes |
| **Track changes over time** | Manual spreadsheets | Automated |
| **Identify high-risk gaps** | Expert knowledge required | Auto-scored |
| **Remediation guidance** | Research needed | Included |
| **Compliance reporting** | Manual documentation | JSON reports |

**Kubescape saves ~7+ hours per audit** while providing consistent results.

## Uninstalling

```bash
kubectl delete -k k8s/optional/high-priority/kubescape/
```

**Your 100/100 perfect score remains intact.**

## Learn More

- **Official Docs**: https://kubescape.io/docs/
- **CIS Benchmark**: https://www.cisecurity.org/benchmark/kubernetes
- **NSA/CISA Guide**: https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF
- **MITRE ATT&CK**: https://attack.mitre.org/matrices/enterprise/containers/
- **GitHub**: https://github.com/kubescape/kubescape
- **CNCF Project Page**: https://www.cncf.io/projects/kubescape/

---

**Remember**: Kubescape is an **optional enhancement** for compliance validation. Your cluster is **already perfect** at 100/100 without it.

---

[Back to Optional Enhancements](../../README.md) | [Falco](../falco/README.md) | [Gatekeeper](../gatekeeper/README.md) | [Main README](../../../../README.md)
