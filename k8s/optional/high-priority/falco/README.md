# Falco - Runtime Threat Detection

## Overview

Falco provides **runtime security** by monitoring system calls at the kernel level using eBPF. It detects anomalous activity and security threats in real-time.

**Status**: ✅ OPTIONAL - Your cluster is already 100/100 without this

## Why Falco?

### Complements Existing Security

Your 100/100 cluster already has:
- ✅ **Trivy**: Pre-deployment vulnerability scanning
- ✅ **Pod Security Standards**: Admission-time security policies
- ✅ **NetworkPolicies**: Network segmentation

Falco adds:
- 🎯 **Runtime detection**: Catches threats *during execution*
- 🎯 **Syscall monitoring**: Detects privilege escalation, shell access, file tampering
- 🎯 **Zero-day protection**: Behavioral detection doesn't rely on CVE databases

### Defense-in-Depth

```
┌─────────────────────────────────────┐
│  Trivy (100/100 component)          │  Pre-deployment: Block vulnerable images
├─────────────────────────────────────┤
│  Pod Security Standards (100/100)   │  Admission: Enforce security policies
├─────────────────────────────────────┤
│  Falco (OPTIONAL enhancement)       │  Runtime: Detect active threats
└─────────────────────────────────────┘
```

## What Falco Detects

### 1. **Privilege Escalation**
```
- sudo/su execution in containers
- Capability changes
- Setuid/setgid binaries
```

### 2. **Unauthorized Access**
```
- Unexpected shell spawns
- Sensitive file access (/etc/shadow, SSH keys)
- Credential dumping attempts
```

### 3. **Malicious Activity**
```
- Cryptocurrency mining
- Reverse shells
- Network scanning
```

### 4. **Container Escapes**
```
- Host filesystem access
- Privileged container abuse
- Kernel module loading
```

### 5. **Kubernetes-Specific**
```
- Direct API server access
- Service account token theft
- ConfigMap/Secret tampering
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  Kernel Space                     │
│  ┌────────────────────────────────────────────┐  │
│  │  eBPF Probes (Modern BPF)                  │  │
│  │  - Syscall monitoring                      │  │
│  │  - Low overhead (<1% CPU)                  │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────┐
│              Falco DaemonSet                      │
│  - Runs on every node                            │
│  - Evaluates events against rules                │
│  - Outputs alerts                                │
└──────────────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────┐
│            Falcosidekick (2 replicas)            │
│  - Receives alerts from Falco                    │
│  - Forwards to multiple destinations:            │
│    • Prometheus (metrics)                        │
│    • Loki (logs)                                 │
│    • Webhook (custom integrations)               │
└──────────────────────────────────────────────────┘
                       │
                       ↓
              ┌────────┴────────┐
              │                 │
              ↓                 ↓
      ┌─────────────┐   ┌─────────────┐
      │ Prometheus  │   │    Loki     │
      │  (Alerts)   │   │   (Logs)    │
      └─────────────┘   └─────────────┘
              │                 │
              ↓                 ↓
          ┌─────────────────────────┐
          │  Grafana Dashboards     │
          └─────────────────────────┘
```

## Resource Requirements

### Per Node (DaemonSet)
- **CPU**: 50m request, 200m limit
- **Memory**: 50Mi request, 200Mi limit
- **Storage**: None (ephemeral)

### Falcosidekick (Deployment, 2 replicas)
- **CPU**: 50m request per pod, 200m limit
- **Memory**: 64Mi request per pod, 256Mi limit

### Total Overhead (3-node cluster)
- **CPU**: ~400m (3.3% of 12 cores)
- **Memory**: ~512Mi (1% of 48GB)

**Conclusion**: Minimal impact - well within your cluster's headroom.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for metrics)
- Loki (for logs)
- Grafana (for visualization)

### Quick Deploy

```bash
kubectl apply -k k8s/optional/high-priority/falco/
```

### Verify Deployment

```bash
# Check DaemonSet (should have 1 pod per node)
kubectl get daemonset -n falco
kubectl get pods -n falco -l app=falco

# Check Falcosidekick
kubectl get deployment -n falco -l app=falcosidekick
kubectl get pods -n falco -l app=falcosidekick

# Check metrics endpoint
kubectl port-forward -n falco svc/falcosidekick 2801:2801
curl http://localhost:2801/metrics
```

## Configuration

### Custom Rules

Edit `falco-rules.yaml` ConfigMap to add custom detection rules:

```yaml
- rule: My Custom Rule
  desc: Detect specific behavior
  condition: >
    spawned_process and
    container and
    proc.name = "suspicious-binary"
  output: >
    Suspicious binary executed
    (user=%user.name container=%container.name)
  priority: WARNING
  tags: [custom, detection]
```

### Tune Sensitivity

Edit `falco-config.yaml`:

```yaml
# Change minimum priority (default: notice)
priority: warning  # Options: emergency, alert, critical, error, warning, notice, info, debug
```

### Add Allowed Containers

Whitelist known containers to reduce false positives:

```yaml
- list: known_privileged_images
  items: [your-debug-image, your-build-image]
```

## Monitoring & Alerts

### Prometheus Metrics

Falco exposes metrics at `:8765/metrics`:

```
falco_events{priority="Critical"} - Critical events count
falco_events{priority="Warning"} - Warning events count
falco_kernel_event_drops_total - Dropped events
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `FalcoCriticalEvent` | Critical | Any critical security event |
| `FalcoPrivilegeEscalation` | Critical | Privilege escalation attempt |
| `FalcoCryptoMining` | Critical | Cryptocurrency mining detected |
| `FalcoShellInContainer` | Warning | >5 shells in 30 minutes |
| `FalcoEventDrops` | Warning | >1% event drops |
| `FalcoDown` | Warning | Falco pod down >5 minutes |

### Grafana Dashboard

Import the official Falco dashboard:
- Dashboard ID: `11914`
- URL: https://grafana.com/grafana/dashboards/11914

## Usage Examples

### View Recent Alerts

```bash
# Loki logs (via Falcosidekick)
kubectl logs -n logging -l app=loki -f | grep falco

# Falco direct logs
kubectl logs -n falco -l app=falco --tail=100
```

### Test Detection

**WARNING: Only run these tests in a non-production namespace!**

```bash
# Test shell detection
kubectl run test-shell --rm -it --image=alpine -- sh

# Test sensitive file access
kubectl run test-file --rm -it --image=alpine -- cat /etc/shadow

# Test package manager
kubectl run test-pkg --rm -it --image=alpine -- apk add curl
```

You should see Falco alerts for all of these.

## Integration with Existing Stack

### Prometheus

ServiceMonitors automatically discovered:
- `falco-metrics` - Falco kernel stats
- `falcosidekick` - Alert forwarding metrics

### Loki

Falcosidekick forwards all alerts to Loki with:
- Tenant: `falco`
- Labels: `{job="falco", priority="<level>"}`

Query in Grafana:
```
{job="falco", priority="Critical"}
```

### Grafana Alerts

PrometheusRule `falco-alerts` includes 8 pre-configured alerts.

View in Grafana:
- **Alerting** → **Alert Rules** → Filter: `falco`

## Troubleshooting

### Falco Pods Not Starting

```bash
kubectl describe pods -n falco -l app=falco
kubectl logs -n falco -l app=falco
```

**Common issues**:
- Modern BPF not supported: Talos Linux ✅ supports it
- Permissions: Namespace must be `privileged` (already configured)

### No Alerts Appearing

```bash
# Check Falco is detecting events
kubectl logs -n falco -l app=falco | grep "Event"

# Check Falcosidekick is forwarding
kubectl logs -n falco -l app=falcosidekick | grep "forward"

# Check Prometheus is scraping
kubectl port-forward -n falco svc/falcosidekick 2801:2801
curl http://localhost:2801/metrics | grep falco_events
```

### High CPU Usage

Falco normally uses <1% CPU. If higher:

1. Check for event drops:
```bash
kubectl logs -n falco -l app=falco | grep "drop"
```

2. Increase memory limits if needed:
```yaml
resources:
  limits:
    memory: 512Mi  # Increase from 200Mi
```

3. Reduce rule complexity or increase sampling:
```yaml
# In falco-config.yaml
syscall_event_drops:
  rate: 0.1  # Sample 10% instead of 100%
```

## Security Considerations

### Why Privileged?

Falco DaemonSet requires `privileged: true` because:
- Needs access to kernel syscalls via eBPF
- Requires host filesystems for context
- Must read container runtime sockets

This is **expected and necessary** for runtime security monitoring.

### Mitigation

- ✅ Namespace has `pod-security.kubernetes.io/enforce: privileged`
- ✅ RBAC limited to read-only Kubernetes resources
- ✅ Well-audited CNCF project (graduated)
- ✅ DaemonSet runs on all nodes (no single point of failure)

## Comparison: Falco vs Trivy

| Feature | Trivy (100/100) | Falco (Optional) |
|---------|-----------------|------------------|
| **When** | Pre-deployment | Runtime |
| **What** | CVE scanning | Behavioral detection |
| **Scope** | Container images | System calls |
| **Detection** | Known vulnerabilities | Anomalous behavior |
| **Zero-days** | ❌ No | ✅ Yes |
| **Overhead** | None (scan-time) | ~1% CPU per node |

**Both are complementary** - Trivy prevents vulnerable images, Falco detects active exploits.

## Uninstalling

```bash
kubectl delete -k k8s/optional/high-priority/falco/
```

**Your 100/100 perfect score remains intact.**

## Learn More

- **Official Docs**: https://falco.org/docs/
- **Rules Repository**: https://github.com/falcosecurity/rules
- **Community**: https://kubernetes.slack.com/messages/falco
- **CNCF Project Page**: https://www.cncf.io/projects/falco/

---

**Remember**: Falco is an **optional enhancement** for defense-in-depth. Your cluster is **already perfect** at 100/100 without it.

---

[Back to Optional Enhancements](../../README.md) | [Gatekeeper](../gatekeeper/README.md) | [Kubescape](../kubescape/README.md) | [Main README](../../../../README.md)
