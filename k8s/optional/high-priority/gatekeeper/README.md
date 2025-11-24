# OPA Gatekeeper - Policy Enforcement Engine

## Overview

Gatekeeper uses the **Open Policy Agent (OPA)** to enforce custom policies on Kubernetes resources. It provides a **policy-as-code** framework using the Rego language.

**Status**: ✅ OPTIONAL - Your cluster is already 100/100 without this

## Why Gatekeeper?

### Complements Existing Security

Your 100/100 cluster already has:
- ✅ **Pod Security Standards**: Built-in Kubernetes security policies (restricted)
- ✅ **ResourceQuotas**: Namespace-level resource limits
- ✅ **LimitRanges**: Container-level constraints

Gatekeeper adds:
- 🎯 **Custom policies**: Enforce organization-specific requirements
- 🎯 **Audit mode**: Detect violations without blocking
- 🎯 **Policy library**: Reusable constraint templates

### Defense-in-Depth

```
┌─────────────────────────────────────┐
│  Pod Security Standards (100/100)   │  Basic security enforcement
├─────────────────────────────────────┤
│  NetworkPolicies (100/100)          │  Network segmentation
├─────────────────────────────────────┤
│  Gatekeeper (OPTIONAL enhancement)  │  Custom policy enforcement
└─────────────────────────────────────┘
```

## What Gatekeeper Enforces

### 1. **Resource Requirements**
```
✅ All containers must have CPU/memory requests
✅ All containers must have CPU/memory limits
✅ QoS classes properly configured
```

### 2. **Security Best Practices**
```
✅ No :latest image tags
✅ Read-only root filesystem required
✅ No privileged containers (except whitelisted)
✅ Containers must be non-root
```

### 3. **Operational Standards**
```
✅ Liveness and readiness probes required
✅ No resources in default namespace
✅ Required labels on production resources
✅ No LoadBalancer services (use Ingress)
```

### 4. **Compliance**
```
✅ Consistent labeling scheme
✅ Audit trail of all violations
✅ Drift detection (resources modified after deployment)
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│         Kubernetes API Server                     │
└──────────────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────┐
│      Gatekeeper Webhook (3 replicas)             │
│  - Admission controller                          │
│  - Validates CREATE/UPDATE requests              │
│  - Runs OPA Rego policies                        │
│  - Response: Allow/Deny + reason                 │
└──────────────────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
          ↓                         ↓
┌──────────────────┐      ┌──────────────────┐
│ Constraint       │      │  Gatekeeper      │
│ Templates        │      │  Audit           │
│ (Policy Code)    │      │  (1 replica)     │
└──────────────────┘      └──────────────────┘
          │                         │
          │                         ↓
          │               ┌──────────────────┐
          │               │  Audit Reports   │
          │               │  (Violations)    │
          │               └──────────────────┘
          │                         │
          ↓                         ↓
┌──────────────────────────────────────────────────┐
│            Prometheus Metrics                     │
│  - Policy violations                             │
│  - Webhook latency                               │
│  - Template sync status                          │
└──────────────────────────────────────────────────┘
```

## Resource Requirements

### Webhook (3 replicas for HA)
- **CPU**: 100m request per pod, 500m limit
- **Memory**: 256Mi request per pod, 512Mi limit

### Audit Controller (1 replica)
- **CPU**: 100m request, 500m limit
- **Memory**: 256Mi request, 512Mi limit

### Total Overhead (3-node cluster)
- **CPU**: ~400m (7% of 6 cores)
- **Memory**: ~1GB (2% of 48GB)

**Conclusion**: Moderate overhead - well within your cluster's headroom.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for metrics)
- Grafana (for visualization)

### Quick Deploy

```bash
kubectl apply -k k8s/optional/high-priority/gatekeeper/
```

### Verify Deployment

```bash
# Check deployments
kubectl get deployments -n gatekeeper-system
kubectl get pods -n gatekeeper-system

# Check webhook is registered
kubectl get validatingwebhookconfigurations | grep gatekeeper

# Check constraint templates are installed
kubectl get constrainttemplates

# Check constraints are active
kubectl get constraints
```

### Expected Output

```
NAME                                   READY   AGE
gatekeeper-audit                       1/1     2m
gatekeeper-controller-manager          3/3     2m

CONSTRAINTTEMPLATES
k8sblockdefault
k8sblocklatestimage
k8sblockprivileged
k8srequiredlabels
k8srequiredprobes
k8srequiredresources
k8srequirereadonlyroot
k8sblockloadbalancer

CONSTRAINTS
block-default-namespace (K8sBlockDefault)
require-resources (K8sRequiredResources)
block-latest-image (K8sBlockLatestImage)
...
```

## Configuration

### Enforcement Actions

Each constraint has an `enforcementAction`:

1. **deny** - Block violations (production)
2. **dryrun** - Log violations only (testing)
3. **warn** - Allow but warn user

**Default**: Most constraints start with `dryrun` to avoid breaking existing workloads.

### Switching to Enforcement Mode

Once you've reviewed audit reports and fixed violations:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: require-resources
spec:
  enforcementAction: deny  # Changed from 'dryrun'
```

Apply the change:
```bash
kubectl apply -f k8s/optional/high-priority/gatekeeper/constraint-library.yaml
```

### Custom Policies

Create custom constraint templates using Rego:

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8smycustompolicy
spec:
  crd:
    spec:
      names:
        kind: K8sMyCustomPolicy
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8smycustompolicy

        violation[{"msg": msg}] {
          # Your Rego logic here
          input.review.object.metadata.labels["my-label"] != "required-value"
          msg := "Custom policy violation"
        }
```

Then create a constraint:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sMyCustomPolicy
metadata:
  name: my-policy
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  enforcementAction: deny
```

## Monitoring & Audit

### View Violations

```bash
# Get all violations across all constraints
kubectl get constraints -A -o json | jq '.items[] | select(.status.totalViolations > 0) | {name: .metadata.name, violations: .status.totalViolations}'

# Get details of specific constraint
kubectl get k8sblockdefault block-default-namespace -o yaml

# View violations in status
kubectl get k8sblockdefault block-default-namespace -o jsonpath='{.status.violations}'
```

### Prometheus Metrics

Gatekeeper exposes metrics at `:8888/metrics`:

```
gatekeeper_violations{enforcement_action="deny"} - Denied requests
gatekeeper_violations{enforcement_action="dryrun"} - Audit violations
gatekeeper_webhook_request_duration_seconds - Webhook latency
gatekeeper_constraint_templates{status="active"} - Active templates
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `GatekeeperWebhookDown` | Critical | Webhook pod down >5 min |
| `GatekeeperConstraintViolations` | Warning | >0 violations in 15 min |
| `GatekeeperHighLatency` | Warning | P99 latency >1s |
| `GatekeeperWebhookErrors` | Warning | >5% error rate |
| `GatekeeperInvalidTemplates` | Warning | Template errors detected |

### Grafana Dashboard

Import the official Gatekeeper dashboard:
- Dashboard ID: `14333`
- URL: https://grafana.com/grafana/dashboards/14333

## Usage Examples

### Test Policy Enforcement

**Test 1: Block default namespace**

```bash
# This should be DENIED
kubectl run test-pod --image=nginx

# Error: Creating resources in the default namespace is not allowed
```

**Test 2: Block :latest tag**

```bash
# This should be DENIED in production namespace
kubectl run test-pod --image=nginx:latest -n production

# Error: Container <test-pod> uses ':latest' image tag which is not allowed
```

**Test 3: Missing resource limits** (dryrun mode)

```bash
# This will succeed but be logged as violation
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-limits
  namespace: tools
spec:
  containers:
    - name: nginx
      image: nginx:1.25
EOF

# Check audit report
kubectl get k8srequiredresources require-resources -o yaml
```

### Exempting Resources

Add to constraint's `match.excludedNamespaces`:

```yaml
spec:
  match:
    excludedNamespaces:
      - kube-system
      - development  # Add exemption
```

Or exempt specific images for privileged policy:

```yaml
spec:
  parameters:
    exemptImages:
      - "falcosecurity/falco"  # Needs privileged access
      - "my-debug-image"
```

## Integration with Existing Stack

### Pod Security Standards

Gatekeeper complements but **doesn't replace** Pod Security Standards:

| Feature | Pod Security Standards | Gatekeeper |
|---------|------------------------|------------|
| **Scope** | Pod-level security | Any Kubernetes resource |
| **Policies** | Fixed (restricted/baseline/privileged) | Custom Rego code |
| **Audit** | No | Yes (detailed reports) |
| **Dry-run** | No | Yes |

**Both should be used together** for defense-in-depth.

### NetworkPolicies

Gatekeeper can enforce NetworkPolicy requirements:

```yaml
# Custom policy: Require NetworkPolicy in each namespace
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequirenetworkpolicy
spec:
  # Ensures every namespace has at least one NetworkPolicy
```

### Trivy Integration

Gatekeeper can block images based on Trivy scan results:

```yaml
# Future enhancement: Query Trivy API in Rego policy
# Deny images with CRITICAL vulnerabilities
```

## Troubleshooting

### Webhook Not Blocking

```bash
# Check webhook is registered
kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration

# Check pods are running
kubectl get pods -n gatekeeper-system

# Check logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### Policy Not Working

```bash
# Verify constraint template exists
kubectl get constrainttemplate k8sblockdefault

# Verify constraint is created
kubectl get k8sblockdefault

# Check constraint status
kubectl describe k8sblockdefault block-default-namespace

# Look for enforcement action
kubectl get k8sblockdefault block-default-namespace -o jsonpath='{.spec.enforcementAction}'
# Should be "deny" not "dryrun"
```

### High Latency

Gatekeeper adds <50ms latency normally. If higher:

1. Check webhook metrics:
```bash
kubectl port-forward -n gatekeeper-system svc/gatekeeper-metrics 8888:8888
curl http://localhost:8888/metrics | grep request_duration
```

2. Increase replicas if needed:
```yaml
spec:
  replicas: 5  # Increase from 3
```

3. Simplify Rego policies (complex logic adds latency)

### Memory Pressure

If Gatekeeper pods are OOMKilled:

```bash
# Increase memory limits
kubectl edit deployment gatekeeper-controller-manager -n gatekeeper-system

# Set:
resources:
  limits:
    memory: 1Gi  # Increase from 512Mi
```

## Security Considerations

### Webhook Failure Policy

```yaml
failurePolicy: Ignore  # If webhook is down, allow requests
```

**Why**: Prevents cluster lockout if Gatekeeper fails.

**Trade-off**: Policies not enforced during downtime.

**Mitigation**:
- 3 webhook replicas for HA
- PodDisruptionBudget ensures minimum availability
- Monitoring alerts on webhook downtime

### RBAC Permissions

Gatekeeper ServiceAccount has cluster-wide read access:

```yaml
verbs: [get, list, watch]
```

**Why**: Needs to inspect all resources for policy evaluation.

**Mitigation**:
- Read-only access only
- Well-audited CNCF project
- Namespace excluded from its own policies

## Included Policies

### Production-Ready (enforcementAction: deny)

| Policy | Description | Applies To |
|--------|-------------|------------|
| `block-default-namespace` | No resources in default namespace | All resources |
| `block-latest-image` | No :latest tags | production namespace |
| `block-privileged` | No privileged containers | All (except Falco) |

### Audit-Only (enforcementAction: dryrun)

| Policy | Description | Applies To |
|--------|-------------|------------|
| `require-resources` | CPU/memory requests/limits | production namespace |
| `require-readonly-root` | Read-only root filesystem | production namespace |
| `require-probes` | Liveness/readiness probes | production namespace |
| `block-loadbalancer` | Use Ingress instead of LoadBalancer | All services |
| `require-production-labels` | Required labels (app, environment) | production namespace |

**Recommendation**: Review audit violations, fix them, then switch to `deny`.

## Comparison: Gatekeeper vs Pod Security Standards

| Feature | Pod Security Standards | Gatekeeper |
|---------|------------------------|------------|
| **When** | Admission (built-in) | Admission (webhook) |
| **Policies** | 3 levels (restricted/baseline/privileged) | Unlimited custom policies |
| **Language** | N/A (fixed rules) | Rego (policy-as-code) |
| **Audit** | ❌ No historical audit | ✅ Full audit trail |
| **Dry-run** | ❌ No | ✅ Yes (dryrun mode) |
| **Overhead** | None | ~400m CPU, ~1GB RAM |
| **Scope** | Pods only | Any Kubernetes resource |

**Both are complementary** - Pod Security Standards provide baseline, Gatekeeper adds custom policies.

## Uninstalling

```bash
kubectl delete -k k8s/optional/high-priority/gatekeeper/
```

**Your 100/100 perfect score remains intact.**

## Learn More

- **Official Docs**: https://open-policy-agent.github.io/gatekeeper/
- **Rego Language**: https://www.openpolicyagent.org/docs/latest/policy-language/
- **Policy Library**: https://github.com/open-policy-agent/gatekeeper-library
- **Community**: https://kubernetes.slack.com/messages/gatekeeper
- **CNCF Project Page**: https://www.cncf.io/projects/open-policy-agent/

---

**Remember**: Gatekeeper is an **optional enhancement** for custom policy enforcement. Your cluster is **already perfect** at 100/100 without it.
