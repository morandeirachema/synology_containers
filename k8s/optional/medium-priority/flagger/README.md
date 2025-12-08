# Flagger - Progressive Delivery for Kubernetes

## Overview

Flagger is a **progressive delivery operator** that automates the release process for applications running on Kubernetes. It gradually shifts traffic to new versions while measuring metrics and running conformance tests, automatically rolling back on failures.

**Status**: ✅ OPTIONAL - Advanced deployment strategy enhancement

## Why Flagger?

### Replaces Manual Rolling Updates

Without Flagger:
- ❌ Manual canary deployments (complex scripting)
- ❌ No automated rollback on failure
- ❌ Risk of deploying broken releases to all users
- ❌ No gradual traffic shifting capabilities
- ❌ Manual A/B testing setup

Flagger provides:
- ✅ **Automated canary releases**: Gradual traffic shifting with automated rollback
- ✅ **Blue-green deployments**: Zero-downtime instant switchover
- ✅ **A/B testing**: Route traffic based on HTTP headers/cookies
- ✅ **Metric-based promotion**: Use Prometheus metrics to validate releases
- ✅ **Webhook testing**: Run integration tests during rollout
- ✅ **Multi-provider support**: Works with Istio, Linkerd, NGINX, Traefik, Contour

### Progressive Delivery Strategies

```
┌─────────────────────────────────────────────────┐
│  Traditional Deployment (Risky)                 │
├─────────────────────────────────────────────────┤
│  v1 → v2 (instant, all users)                   │
│  ❌ Bug affects everyone immediately            │
│  ❌ No time to detect issues                    │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Flagger Canary (Safe)                          │
├─────────────────────────────────────────────────┤
│  v1 (100%) → v2 (10%) → v2 (25%) → v2 (50%)    │
│              ↓            ↓            ↓         │
│          ✅ Metrics   ✅ Metrics   ✅ Metrics   │
│  ✅ Auto-rollback if failure detected           │
│  ✅ Only small % of users affected by bugs      │
└─────────────────────────────────────────────────┘
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│              Flagger Operator                     │
│  - Watches Canary resources                      │
│  - Creates primary and canary deployments        │
│  - Controls traffic shifting                     │
│  - Queries Prometheus for metrics                │
│  - Triggers webhooks for testing                 │
└──────────────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ↓           ↓           ↓
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│  Ingress/    │ │Prometheus│ │  Webhooks    │
│  Service     │ │ (Metrics)│ │  (Tests)     │
│  Mesh        │ │          │ │              │
└──────────────┘ └──────────┘ └──────────────┘
         │
         ↓
┌──────────────────────────────────────────────────┐
│         Application Deployments                  │
│  ┌────────────────┐    ┌────────────────┐       │
│  │  Primary (v1)  │    │  Canary (v2)   │       │
│  │  90% traffic   │    │  10% traffic   │       │
│  └────────────────┘    └────────────────┘       │
└──────────────────────────────────────────────────┘
```

### How Canary Deployments Work

```
Step 1: Initialize
┌────────────────────────────────────┐
│  Primary (v1): 100% traffic        │
│  Canary (v1):  0% traffic          │
└────────────────────────────────────┘

Step 2: New version detected (v2)
┌────────────────────────────────────┐
│  Primary (v1): 90% traffic         │
│  Canary (v2):  10% traffic         │
│  ↓ Wait for analysis interval      │
└────────────────────────────────────┘

Step 3: Metrics check PASSED ✅
┌────────────────────────────────────┐
│  Primary (v1): 75% traffic         │
│  Canary (v2):  25% traffic         │
│  ↓ Wait for analysis interval      │
└────────────────────────────────────┘

Step 4: Metrics check PASSED ✅
┌────────────────────────────────────┐
│  Primary (v1): 50% traffic         │
│  Canary (v2):  50% traffic         │
│  ↓ Wait for analysis interval      │
└────────────────────────────────────┘

Step 5: Metrics check PASSED ✅
┌────────────────────────────────────┐
│  Primary (v1): 0% traffic          │
│  Canary (v2):  100% traffic        │
│  ↓ Promotion                       │
└────────────────────────────────────┘

Step 6: Promotion complete
┌────────────────────────────────────┐
│  Primary (v2): 100% traffic        │
│  Canary (v2):  0% traffic          │
│  Ready for next deployment         │
└────────────────────────────────────┘

If metrics check FAILS at any step ❌:
┌────────────────────────────────────┐
│  Automatic Rollback                │
│  Primary (v1): 100% traffic        │
│  Canary (v2):  0% traffic (scaled) │
│  ⚠️  Alert triggered               │
└────────────────────────────────────┘
```

## Features

### Deployment Strategies

**1. Canary Release (Gradual)**
- Slowly increase traffic to new version
- Metrics-based validation at each step
- Automatic rollback on failure
- Use case: Production releases

**2. Blue-Green (Instant Switch)**
- New version gets no traffic initially
- Run tests against blue (new) version
- Instant 100% traffic switch when validated
- Use case: Zero-downtime upgrades

**3. A/B Testing (Header-based)**
- Route specific users to new version
- Based on HTTP headers, cookies, or user agent
- Compare metrics between versions
- Use case: Feature validation

**4. Mirroring (Shadow Traffic)**
- Send copy of production traffic to new version
- No real users affected
- Compare responses/metrics
- Use case: Performance testing

### Metric Providers

Flagger validates releases using metrics from:
- **Prometheus**: Custom queries (error rate, latency, etc.)
- **Datadog**: APM metrics
- **New Relic**: Application performance
- **CloudWatch**: AWS metrics
- **Graphite**: Time series data

### Traffic Routing

Supported ingress controllers and service meshes:
- **NGINX Ingress**: Header-based routing
- **Traefik**: Weight-based traffic shifting
- **Istio**: Full service mesh capabilities
- **Linkerd**: Progressive delivery with service mesh
- **Contour**: Envoy-based ingress

## Resource Requirements

### Flagger Operator (1 replica)
- **CPU**: 100m request, 500m limit
- **Memory**: 128Mi request, 512Mi limit
- **Storage**: None (ephemeral)

### Per Canary Deployment
- **Additional resources**: ~1 extra pod during rollout
- **Network overhead**: Minimal (traffic splitting)

### Total Overhead (Operator only)
- **CPU**: ~100m
- **Memory**: ~128Mi

**Conclusion**: Minimal overhead - only temporary extra pod during rollouts.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for metrics)
- Ingress controller (NGINX, Traefik, etc.)
- Grafana (optional, for visualization)

### Quick Deploy Operator

```bash
kubectl apply -k k8s/optional/medium-priority/flagger/
```

### Verify Deployment

```bash
# Check operator is running
kubectl get deployment -n flagger-system
kubectl get pods -n flagger-system

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# flagger-xxxxxxxxxx-xxxxx  1/1     Running   0          1m

# Check CRD is installed
kubectl get crd canaries.flagger.app

# Check metrics endpoint
kubectl port-forward -n flagger-system svc/flagger 8080:8080
curl http://localhost:8080/metrics
```

## Configuration

### Basic Canary Release

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
  namespace: production
spec:
  # Target deployment to manage
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  # Service configuration
  service:
    port: 80
    targetPort: 8080

  # Canary analysis configuration
  analysis:
    # Analysis interval (how often to check metrics)
    interval: 1m

    # Number of successful iterations before promotion
    threshold: 5

    # Max traffic percentage routed to canary
    maxWeight: 50

    # Traffic increment step
    stepWeight: 10

    # Metrics to validate
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99  # 99% success rate required
        interval: 1m

      - name: request-duration
        thresholdRange:
          max: 500  # Max 500ms P99 latency
        interval: 1m

    # Prometheus queries for metrics
    metricsServer: "http://prometheus-operated.monitoring:9090"
```

### Blue-Green Deployment

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  service:
    port: 80

  analysis:
    interval: 1m
    threshold: 10
    iterations: 10  # Run tests for 10 minutes

    # Blue-Green: No traffic to canary initially
    maxWeight: 0

    # Webhook tests (pre-promotion)
    webhooks:
      - name: integration-tests
        url: http://test-runner.ci/run
        timeout: 5m
        metadata:
          type: pre-rollout
          cmd: "kubectl run test --rm -it --image=test-suite"

      - name: acceptance-tests
        url: http://test-runner.ci/acceptance
        timeout: 10m

  # After all tests pass, instant switch to 100%
  confirm-promotion: true
```

### A/B Testing (Header-based)

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  service:
    port: 80

  # A/B testing configuration
  analysis:
    interval: 1m
    threshold: 100
    iterations: 10

    # Route 50% of users with specific header to canary
    match:
      - headers:
          x-canary:
            exact: "insider"

    metrics:
      - name: conversion-rate
        thresholdRange:
          min: 10  # Require 10% conversion rate
        templateRef:
          name: conversion-rate
          namespace: flagger-system

  # Session affinity
  sessionAffinity:
    cookieName: flagger-cookie
    maxAge: 86400
```

### With Prometheus Metrics

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  service:
    port: 9898

  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10

    # Built-in metrics (for Prometheus)
    metrics:
      # HTTP success rate
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m

      # Request duration (P99)
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m

      # Custom metric
      - name: error-rate
        templateRef:
          name: error-rate
          namespace: flagger-system
        thresholdRange:
          max: 5  # Max 5% error rate
        interval: 1m
```

### Custom Metric Template

```yaml
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: error-rate
  namespace: flagger-system
spec:
  provider:
    type: prometheus
    address: http://prometheus-operated.monitoring:9090

  query: |
    100 - sum(
      rate(
        http_requests_total{
          namespace="{{ namespace }}",
          deployment="{{ target }}",
          status!~"5.."
        }[{{ interval }}]
      )
    )
    /
    sum(
      rate(
        http_requests_total{
          namespace="{{ namespace }}",
          deployment="{{ target }}"
        }[{{ interval }}]
      )
    ) * 100
```

## Usage Examples

### Deploy Your First Canary

**Step 1: Create deployment**

```bash
kubectl create deployment myapp --image=nginx:1.25 -n production
kubectl expose deployment myapp --port=80 --target-port=80 -n production
```

**Step 2: Create Canary resource**

```bash
kubectl apply -f - <<EOF
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  service:
    port: 80

  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10

    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
EOF
```

**Step 3: Trigger canary deployment**

```bash
# Update image to trigger canary
kubectl set image deployment/myapp myapp=nginx:1.26 -n production

# Watch canary progress
kubectl get canary myapp -n production -w
```

**Expected output**:
```
NAME    STATUS        WEIGHT   LASTTRANSITIONTIME
myapp   Initialized   0        2025-11-24T12:00:00Z
myapp   Progressing   10       2025-11-24T12:01:00Z
myapp   Progressing   20       2025-11-24T12:02:00Z
myapp   Progressing   30       2025-11-24T12:03:00Z
myapp   Progressing   40       2025-11-24T12:04:00Z
myapp   Progressing   50       2025-11-24T12:05:00Z
myapp   Promoting     0        2025-11-24T12:06:00Z
myapp   Succeeded     0        2025-11-24T12:07:00Z
```

### Monitor Canary Progress

```bash
# Watch canary status
kubectl get canary -A -w

# Describe canary for details
kubectl describe canary myapp -n production

# Check events
kubectl get events -n production --field-selector involvedObject.name=myapp

# View Flagger logs
kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger -f
```

### Rollback on Failure

Flagger automatically rolls back if metrics fail:

```bash
# Simulate failure by deploying broken version
kubectl set image deployment/myapp myapp=broken:latest -n production

# Watch automatic rollback
kubectl get canary myapp -n production -w

# Expected:
# NAME    STATUS   WEIGHT   LASTTRANSITIONTIME
# myapp   Failed   0        2025-11-24T12:10:00Z
# ⚠️  Canary deployment failed! Rolled back to previous version.
```

### Manual Approval Gates

For production, require manual confirmation before promotion:

```yaml
spec:
  analysis:
    # ... other settings ...

    # Wait for manual confirmation
    confirm-promotion: true
```

Approve promotion:
```bash
# After manual testing/validation
kubectl annotate canary myapp -n production \
  flagger.app/promote="true"
```

## Monitoring & Alerts

### Prometheus Metrics

Flagger exposes metrics at `:8080/metrics`:

```
flagger_canary_total{namespace, name} - Total canaries
flagger_canary_status{namespace, name, status} - Canary status (0=failed, 1=succeeded, 2=running)
flagger_canary_weight{namespace, name} - Current canary weight %
flagger_canary_duration_seconds{namespace, name} - Canary duration
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `FlaggerDown` | Critical | Flagger pod down >5 min |
| `FlaggerCanaryFailed` | Critical | Canary deployment failed |
| `FlaggerCanaryStuck` | Warning | Canary stuck in progressing state >30 min |
| `FlaggerHighFailureRate` | Warning | >20% canaries failing |

### Grafana Dashboard

Official Flagger dashboard:
- **Dashboard ID**: `15513`
- **URL**: https://grafana.com/grafana/dashboards/15513

Includes:
- Canary success/failure rate
- Deployment duration
- Traffic weight progression
- Active canaries status

### Canary Events

Flagger generates Kubernetes events for all canary lifecycle stages:

```bash
# View canary events
kubectl get events -n production --field-selector involvedObject.name=myapp

# Example events:
# Normal   Synced              Canary initialized
# Normal   Progressing         Advance myapp.production canary weight 10
# Normal   Progressing         Advance myapp.production canary weight 20
# Warning  HighErrorRate       Canary metrics check failed: error rate above threshold
# Warning  Rolled back         Canary failed, rolling back to previous version
```

## Integration with Existing Stack

### Prometheus

Flagger queries Prometheus for:
- HTTP request success rate
- Request duration (P50, P95, P99)
- Custom application metrics

**No changes needed** - uses your existing Prometheus.

Configure Prometheus endpoint:
```yaml
spec:
  analysis:
    metricsServer: "http://prometheus-operated.monitoring:9090"
```

### NGINX Ingress

Flagger works with NGINX Ingress for traffic splitting:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  provider: nginx  # Use NGINX for traffic routing

  ingressRef:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    name: myapp

  analysis:
    # ... metrics configuration ...
```

Flagger automatically manages NGINX Ingress `canary-weight` annotation.

### Grafana

Import Flagger dashboard (#15513) for visualization.

Create alerts in Grafana for:
- Canary failures
- Long-running canaries
- High rollback rate

## Troubleshooting

### Canary Stuck in "Initializing"

```bash
# Check Flagger logs
kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger | grep ERROR

# Common issues:
# - Target deployment not found
# - Service selector mismatch
# - Missing RBAC permissions
```

**Solution**:
```bash
# Verify deployment exists
kubectl get deployment myapp -n production

# Verify service exists and matches deployment labels
kubectl get svc myapp -n production -o yaml
kubectl get deployment myapp -n production -o yaml | grep labels: -A 5
```

### Canary Immediately Rolls Back

```bash
# Check metric configuration
kubectl describe canary myapp -n production

# View conditions and events
kubectl get events -n production --field-selector involvedObject.name=myapp

# Common issues:
# - Metrics query returns no data
# - Threshold too strict (e.g., 100% success rate)
# - Prometheus endpoint unreachable
```

**Solution**:
```bash
# Test Prometheus query manually
kubectl port-forward -n monitoring prometheus-operated-0 9090:9090

# Visit http://localhost:9090 and test query:
# sum(rate(http_requests_total{status!~"5.."}[1m])) / sum(rate(http_requests_total[1m])) * 100

# Adjust thresholds if too strict:
spec:
  analysis:
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 95  # Reduce from 99 to 95
```

### No Traffic Reaching Canary

```bash
# Check canary weight
kubectl get canary myapp -n production -o jsonpath='{.status.canaryWeight}'

# Check service endpoints
kubectl get endpoints myapp-canary -n production

# Check pod status
kubectl get pods -n production -l app=myapp

# For NGINX Ingress, check annotations
kubectl get ingress myapp -n production -o yaml | grep canary
```

### Prometheus Metrics Missing

```bash
# Verify Prometheus is reachable from Flagger
kubectl exec -n flagger-system -l app.kubernetes.io/name=flagger -- \
  wget -qO- http://prometheus-operated.monitoring:9090/api/v1/query?query=up

# Check if your app exposes metrics
kubectl port-forward -n production myapp-xxx 8080:8080
curl http://localhost:8080/metrics

# Ensure ServiceMonitor exists for your app
kubectl get servicemonitor -n production
```

## Security Considerations

### RBAC Permissions

Flagger ServiceAccount has namespace-scoped permissions:

```yaml
verbs: ["get", "list", "watch", "create", "update", "patch"]
resources:
  - deployments
  - services
  - ingresses
  - virtualservices  # For Istio
```

**Why**: Needs to manage deployments, services, and traffic routing.

**Mitigation**:
- ✅ Namespace-scoped (not cluster-wide)
- ✅ Only manages resources with Canary CRD
- ✅ Read-only access to metrics
- ✅ CNCF sandbox project (under incubation)

### Blast Radius Limitation

Canary deployments limit impact of bad releases:

**Traditional deployment**:
- 100% of users affected immediately by bugs

**Canary deployment**:
- Only 10-50% max affected (configurable)
- Automatic rollback reduces exposure time
- Metrics detect issues before full rollout

**Example**: 1% error rate increase detected at 20% canary weight
- Impact: Only 0.2% of total requests affected (1% × 20%)
- vs Traditional: 1% of ALL requests affected

## Comparison: Flagger vs Alternatives

| Feature | Flagger | Argo Rollouts | Spinnaker |
|---------|---------|---------------|-----------|
| **License** | Apache 2.0 (Open) | Apache 2.0 (Open) | Apache 2.0 (Open) |
| **Architecture** | Kubernetes Operator | Kubernetes Operator | Separate platform |
| **Complexity** | Low (CRD-based) | Low (CRD-based) | High (many components) |
| **Traffic routing** | Ingress/Service Mesh | Ingress/Service Mesh | Requires plugins |
| **Metrics providers** | Multiple (Prometheus, Datadog, etc.) | Multiple | Multiple |
| **Installation** | Single deployment | Single deployment | Complex (10+ services) |
| **Learning curve** | Easy | Easy | Steep |
| **GitOps friendly** | ✅ Yes | ✅ Yes | ⚠️ Limited |
| **Webhook support** | ✅ Yes | ✅ Yes | ✅ Yes |
| **UI** | ❌ No (use Grafana) | ❌ No (use Grafana) | ✅ Yes (built-in) |
| **Blue-Green** | ✅ Yes | ✅ Yes | ✅ Yes |
| **A/B testing** | ✅ Yes | ✅ Yes | ✅ Yes |

**Recommendation**: **Flagger for simplicity**. Argo Rollouts if already using Argo. Spinnaker only for large enterprises needing UI.

## Use Cases

### 1. Microservices Deployment

**Problem**: Deploy 20 microservices safely to production.

**Solution**: Apply Canary resources to all microservices.

```bash
# Each microservice gets automatic progressive delivery
for svc in api web auth payment; do
  kubectl apply -f canaries/${svc}-canary.yaml
done
```

**Result**: Each service rolls out gradually, automatic rollback on failure.

### 2. Database Migration

**Problem**: Application v2 requires database schema changes.

**Solution**: Use blue-green deployment.

```yaml
spec:
  analysis:
    maxWeight: 0  # Blue-green mode
    webhooks:
      - name: db-migration
        url: http://migration-runner/apply
        type: pre-rollout
```

**Result**: Migration runs, tests validate, instant switch on success.

### 3. Feature Flag Alternative

**Problem**: Test new feature with subset of users.

**Solution**: A/B testing based on header.

```yaml
spec:
  analysis:
    match:
      - headers:
          x-feature-beta:
            exact: "enabled"
```

**Result**: Users with header see new feature, metrics compare A vs B.

## Example Scenarios

### Scenario 1: Successful Canary Promotion

```bash
# Initial state
$ kubectl get canary myapp -n production
NAME    STATUS        WEIGHT   LASTTRANSITIONTIME
myapp   Initialized   0        2025-11-24T10:00:00Z

# Deploy new version
$ kubectl set image deployment/myapp myapp=nginx:1.26 -n production

# Canary progression
$ kubectl get canary myapp -n production -w
NAME    STATUS        WEIGHT   LASTTRANSITIONTIME
myapp   Progressing   10       2025-11-24T10:01:00Z  # ✅ Metrics OK, advance
myapp   Progressing   20       2025-11-24T10:02:00Z  # ✅ Metrics OK, advance
myapp   Progressing   30       2025-11-24T10:03:00Z  # ✅ Metrics OK, advance
myapp   Progressing   40       2025-11-24T10:04:00Z  # ✅ Metrics OK, advance
myapp   Progressing   50       2025-11-24T10:05:00Z  # ✅ Metrics OK, advance
myapp   Promoting     0        2025-11-24T10:06:00Z  # ✅ All checks passed
myapp   Succeeded     0        2025-11-24T10:07:00Z  # ✅ Promotion complete

# Result: New version successfully deployed to all users
```

### Scenario 2: Automatic Rollback

```bash
# Deploy buggy version (high error rate)
$ kubectl set image deployment/myapp myapp=buggy:latest -n production

# Canary progression
$ kubectl get canary myapp -n production -w
NAME    STATUS        WEIGHT   LASTTRANSITIONTIME
myapp   Progressing   10       2025-11-24T11:01:00Z  # ✅ Metrics OK
myapp   Progressing   20       2025-11-24T11:02:00Z  # ❌ Error rate spike!
myapp   Failed        0        2025-11-24T11:02:30Z  # ❌ Rollback initiated

# Check events
$ kubectl get events -n production --field-selector involvedObject.name=myapp
LAST SEEN   TYPE      REASON       MESSAGE
1m          Warning   Synced       Halt advancement error rate 15.5% > 5%
1m          Warning   Synced       Rolling back myapp.production failed checks threshold reached 5

# Result: Only 20% of users affected briefly, automatic rollback protects remaining 80%
```

## Uninstalling

### Remove Example Canaries

```bash
# List all canaries
kubectl get canaries -A

# Delete specific canary
kubectl delete canary myapp -n production
```

**Note**: This DOES NOT delete your deployment, only the Canary resource.

### Remove Operator

```bash
kubectl delete -k k8s/optional/medium-priority/flagger/
```

**Your deployments continue running normally** without progressive delivery.

## Learn More

- **Official Docs**: https://docs.flagger.app/
- **GitHub**: https://github.com/fluxcd/flagger
- **CNCF**: https://www.cncf.io/projects/flagger/
- **Slack**: https://cloud-native.slack.com/messages/flagger
- **Tutorials**: https://docs.flagger.app/tutorials/

### Recommended Resources

- **Canary Deployment Guide**: https://docs.flagger.app/usage/deployment-strategies#canary-release
- **Blue-Green Guide**: https://docs.flagger.app/usage/deployment-strategies#blue-green
- **A/B Testing Guide**: https://docs.flagger.app/usage/deployment-strategies#ab-testing
- **Metrics Analysis**: https://docs.flagger.app/usage/metrics
- **Webhooks**: https://docs.flagger.app/usage/webhooks

---

**Remember**: Flagger is an **optional enhancement** for progressive delivery and advanced deployment strategies. Your cluster is **already perfect** at 100/100 without it.

---

[Back to Optional Enhancements](../../README.md) | [CloudNativePG](../cloudnative-pg/README.md) | [OpenCost](../opencost/README.md) | [Main README](../../../../README.md)
