# Chaos Mesh - Chaos Engineering Platform

## Overview

Chaos Mesh is a **cloud-native chaos engineering platform** that orchestrates chaos experiments on Kubernetes clusters to test resilience, validate failure scenarios, and improve system reliability.

**Status**: ✅ OPTIONAL - Educational/testing tool for validating cluster resilience

## Why Chaos Engineering?

### Proactive Resilience Testing

Your 100/100 cluster already has:
- ✅ **PodDisruptionBudgets**: Prevent cascading failures
- ✅ **NetworkPolicies**: Network segmentation
- ✅ **Resource limits**: Prevent resource exhaustion
- ✅ **Health checks**: Liveness/readiness probes

Chaos Mesh validates:
- 🎯 **Do PDBs actually work?** Test by killing pods
- 🎯 **Does HPA scale correctly?** Test with CPU/memory stress
- 🎯 **Are apps resilient to network issues?** Inject latency/packet loss
- 🎯 **Can systems survive failures?** Test multi-pod failures

### Philosophy: Break Things on Purpose

```
"Everything fails all the time" - Werner Vogels, AWS CTO

Better to discover weaknesses in a controlled test environment
than during a real outage affecting users.
```

## What is Chaos Engineering?

Chaos Engineering is the discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions.

**Process**:
1. Define steady state (normal operation metrics)
2. Hypothesize steady state continues during chaos
3. Inject real-world failure (pod kills, network issues, etc.)
4. Observe if hypothesis holds
5. Learn and improve resilience

## Architecture

```
┌──────────────────────────────────────────────────┐
│                Chaos Dashboard                    │
│  - Web UI for creating experiments               │
│  - Visualize running chaos                       │
│  - View experiment history                       │
│  Port: 2333                                      │
└──────────────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────┐
│           Chaos Controller Manager               │
│  - Reconciles Chaos CRDs                         │
│  - Schedules chaos experiments                   │
│  - Manages experiment lifecycle                  │
└──────────────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────┐
│              Chaos Daemon (DaemonSet)            │
│  - Runs on every node                            │
│  - Executes chaos actions:                       │
│    • Pod failures (kill, container kill)         │
│    • Network chaos (delay, loss, corrupt)        │
│    • Stress testing (CPU, memory)                │
│    • I/O chaos (latency, errors)                 │
│    • Time chaos (clock skew)                     │
│    • Kernel chaos (system calls)                 │
└──────────────────────────────────────────────────┘
                       │
                       ↓
              ┌────────┴────────┐
              │                 │
              ↓                 ↓
      ┌─────────────┐   ┌─────────────┐
      │Target Pods  │   │ Target Pods │
      │ (Test Chaos)│   │(Test Chaos) │
      └─────────────┘   └─────────────┘
```

## Features

### 1. **Pod Chaos**
Simulate pod-level failures:
- **pod-kill**: Terminate pods (test PDBs, StatefulSet recovery)
- **pod-failure**: Make pods inaccessible (test service discovery)
- **container-kill**: Kill specific containers (test multi-container pods)

### 2. **Network Chaos**
Inject network faults:
- **delay**: Add latency (test timeout handling)
- **loss**: Drop packets (test retry logic)
- **duplicate**: Duplicate packets (test idempotency)
- **corrupt**: Corrupt packets (test error handling)
- **partition**: Network segmentation (test split-brain scenarios)
- **bandwidth**: Limit bandwidth (test throttling)

### 3. **Stress Chaos**
Resource exhaustion testing:
- **CPU stress**: Max out CPU (test resource limits, HPA)
- **Memory stress**: Consume memory (test OOMKiller, limits)

### 4. **I/O Chaos**
Disk operation failures:
- **latency**: Slow disk operations (test timeouts)
- **errno**: Return errors on I/O (test error handling)
- **fault**: Inject read/write faults

### 5. **Time Chaos**
Clock skew simulation:
- **time offset**: Shift time forward/backward
- Test time-sensitive operations (TTLs, certificates, timers)

### 6. **Kernel Chaos**
System call failures:
- Inject syscall errors
- Test low-level error handling

### 7. **DNS Chaos**
DNS failures:
- **error**: Return DNS errors
- **random**: Random DNS responses
- Test service discovery resilience

### 8. **HTTP Chaos**
Application-level faults:
- **abort**: Return specific HTTP codes
- **delay**: Add HTTP response latency
- **patch**: Modify HTTP requests/responses

## Resource Requirements

### Controller Manager (1 replica)
- **CPU**: 100m request, 500m limit
- **Memory**: 128Mi request, 512Mi limit
- **Storage**: None (ephemeral)

### Chaos Daemon (DaemonSet - per node)
- **CPU**: 100m request, 500m limit
- **Memory**: 128Mi request, 512Mi limit
- **Storage**: None (ephemeral)

### Chaos Dashboard (1 replica)
- **CPU**: 50m request, 200m limit
- **Memory**: 64Mi request, 256Mi limit
- **Storage**: None (ephemeral)

### Total Overhead (3-node cluster)
- **CPU**: ~450m (3.8% of 12 cores)
- **Memory**: ~576Mi (1.2% of 48GB)

**Conclusion**: Minimal impact - acceptable for testing/learning environment.

## Safety Considerations

### ⚠️ USE IN TEST ENVIRONMENTS ONLY

**NEVER run chaos experiments on production clusters without:**
1. Thorough testing in non-production first
2. Explicit approval from stakeholders
3. Monitoring and alerting in place
4. Rollback procedures ready
5. Scheduled maintenance windows

### Built-in Safety Features

```yaml
# Chaos experiments have safeguards:
spec:
  # 1. Namespace isolation
  selector:
    namespaces: [chaos-test]  # Only affect test namespace

  # 2. Label selectors
  selector:
    labelSelectors:
      "chaos-ready": "true"  # Only pods explicitly labeled

  # 3. Time limits
  duration: "30s"  # Auto-recover after 30 seconds

  # 4. Scheduler
  scheduler:
    cron: "@every 1h"  # Controlled execution times
```

### Recommended Practices

1. **Start small**: Single pod, short duration (10s)
2. **Use test namespaces**: Isolate chaos from critical workloads
3. **Label explicitly**: Use `chaos-ready: true` label
4. **Set short durations**: 30s-2m max for learning
5. **Monitor actively**: Watch metrics during experiments
6. **Document experiments**: Record hypothesis and results

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for observing chaos impact)
- Grafana (for visualization)
- PodDisruptionBudgets (to test)

### Quick Deploy

```bash
kubectl apply -k k8s/optional/low-priority/chaos-mesh/
```

### Verify Deployment

```bash
# Check controller manager
kubectl get deployment -n chaos-mesh chaos-controller-manager
kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=controller-manager

# Check chaos daemon (should have 1 pod per node)
kubectl get daemonset -n chaos-mesh chaos-daemon
kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=chaos-daemon

# Check dashboard
kubectl get deployment -n chaos-mesh chaos-dashboard
kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=chaos-dashboard

# Check CRDs
kubectl get crd | grep chaos-mesh.org
```

Expected CRDs:
- `podchaos.chaos-mesh.org`
- `networkchaos.chaos-mesh.org`
- `stresschaos.chaos-mesh.org`
- `iochaos.chaos-mesh.org`
- `timechaos.chaos-mesh.org`
- `kernelchaos.chaos-mesh.org`
- `dnschaos.chaos-mesh.org`
- `httpchaos.chaos-mesh.org`

## Configuration

### Access Chaos Dashboard

```bash
# Port-forward to dashboard
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333

# Open browser
open http://localhost:2333
```

**Dashboard features**:
- Create experiments via GUI
- Monitor running chaos
- View experiment logs
- Analyze results

### Create Test Namespace

```bash
# Create isolated namespace for chaos testing
kubectl create namespace chaos-test

# Label namespace for easy identification
kubectl label namespace chaos-test chaos-enabled=true
```

### Deploy Test Application

```yaml
# Example: nginx deployment for chaos testing
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-chaos-test
  namespace: chaos-test
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        chaos-ready: "true"  # Explicit opt-in
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 64Mi
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: chaos-test
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
# PodDisruptionBudget to test
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-pdb
  namespace: chaos-test
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: nginx
```

## Usage Examples

### Example 1: Test PodDisruptionBudget (Pod Kill)

See `examples/pod-kill-experiment.yaml`

**Hypothesis**: PDB ensures at least 1 nginx pod remains running

```bash
# Deploy test app with PDB
kubectl apply -f examples/pod-kill-experiment.yaml

# Watch pods during chaos
kubectl get pods -n chaos-test -w

# Apply pod-kill chaos
kubectl apply -f examples/pod-kill-experiment.yaml

# Observe:
# - Pods are killed one at a time
# - At least 1 pod always remains running (PDB enforced)
# - Killed pods are recreated by ReplicaSet
```

**Expected outcome**: PDB prevents killing last pod, service remains available.

### Example 2: Test Network Resilience (Latency)

See `examples/network-chaos-experiment.yaml`

**Hypothesis**: App handles 100ms network latency gracefully

```bash
# Apply network delay
kubectl apply -f examples/network-chaos-experiment.yaml

# Test service (should be slower but functional)
kubectl run curl --rm -it --image=curlimages/curl --restart=Never \
  -- curl -w "@curl-format.txt" http://nginx.chaos-test

# Observe:
# - Response times increase by ~100ms
# - Requests still succeed (no timeouts)
# - App remains available
```

**Expected outcome**: Service degrades but remains functional.

### Example 3: Test Resource Limits (CPU Stress)

See `examples/cpu-stress-experiment.yaml`

**Hypothesis**: CPU limits prevent stress from affecting other pods

```bash
# Apply CPU stress
kubectl apply -f examples/cpu-stress-experiment.yaml

# Monitor CPU usage
kubectl top pods -n chaos-test

# Check HPA scaling (if configured)
kubectl get hpa -n chaos-test -w

# Observe:
# - CPU hits 100m limit
# - Other pods unaffected
# - HPA may trigger (if configured)
# - OOMKiller NOT triggered (memory within limits)
```

**Expected outcome**: Resource limits contain the blast radius.

### Example 4: Test Distributed System (Network Partition)

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: partition-test
  namespace: chaos-test
spec:
  action: partition
  mode: all
  selector:
    namespaces: [chaos-test]
    labelSelectors:
      "app": "frontend"
  direction: to
  target:
    selector:
      namespaces: [chaos-test]
      labelSelectors:
        "app": "backend"
  duration: "1m"
```

**Use case**: Test if frontend handles backend unavailability.

### Example 5: Time Travel (Certificate Testing)

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: TimeChaos
metadata:
  name: time-shift
  namespace: chaos-test
spec:
  mode: all
  selector:
    namespaces: [chaos-test]
    labelSelectors:
      "app": "time-sensitive"
  timeOffset: "8760h"  # +1 year (test cert expiration)
  duration: "5m"
```

**Use case**: Validate cert renewal before actual expiration.

## Monitoring & Observability

### Chaos Experiment Metrics

Chaos Mesh exposes metrics at `:10080/metrics`:

```
chaos_mesh_experiments_total - Total experiments run
chaos_mesh_experiment_status{name, namespace, kind} - Experiment status (0=stopped, 1=running)
chaos_mesh_daemon_health - Chaos daemon health
```

### Monitoring Chaos Impact

**While chaos is running**, monitor target application:

```bash
# Watch pod status
kubectl get pods -n chaos-test -w

# Monitor resource usage
kubectl top pods -n chaos-test --watch

# Check service availability
kubectl run curl --rm -it --image=curlimages/curl --restart=Never \
  --command -- sh -c 'while true; do curl -s -o /dev/null -w "%{http_code}\n" http://nginx.chaos-test; sleep 1; done'

# Watch Prometheus metrics
# Look for: request latency, error rates, pod restarts
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `ChaosControllerDown` | Warning | Controller pod down >5 min |
| `ChaosDaemonDown` | Warning | Daemon pod down on any node |
| `ChaosExperimentStuck` | Warning | Experiment running >1 hour |

**Note**: Alerts for target applications (error rates, latency) should already exist via your monitoring stack.

### Grafana Dashboard

**Import Chaos Mesh dashboard**:
- **Dashboard ID**: `15630`
- **URL**: https://grafana.com/grafana/dashboards/15630

**Metrics to track during chaos**:
- Service latency (p50, p95, p99)
- Error rates (4xx, 5xx)
- Pod restart counts
- Resource utilization
- Service availability (uptime)

## Troubleshooting

### Chaos Experiment Not Starting

```bash
# Check experiment status
kubectl describe podchaos pod-kill-test -n chaos-test

# Common issues:
# 1. No matching pods (check selectors)
kubectl get pods -n chaos-test -l chaos-ready=true

# 2. Insufficient permissions (check RBAC)
kubectl logs -n chaos-mesh -l app.kubernetes.io/component=controller-manager

# 3. Daemon not running
kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=chaos-daemon
```

### Chaos Not Stopping After Duration

```bash
# Manually stop chaos
kubectl delete podchaos pod-kill-test -n chaos-test

# Check if finalizers are blocking
kubectl get podchaos pod-kill-test -n chaos-test -o yaml

# Force delete if stuck
kubectl patch podchaos pod-kill-test -n chaos-test -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete podchaos pod-kill-test -n chaos-test --force --grace-period=0
```

### Dashboard Not Accessible

```bash
# Check dashboard pod
kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=chaos-dashboard
kubectl logs -n chaos-mesh -l app.kubernetes.io/component=chaos-dashboard

# Verify service
kubectl get svc -n chaos-mesh chaos-dashboard

# Port-forward manually
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```

### Permission Denied Errors

Chaos Mesh requires elevated privileges for some operations:

```bash
# Check namespace security labels
kubectl get namespace chaos-mesh -o yaml | grep pod-security

# Expected: privileged enforcement (chaos-daemon needs host access)
```

### Chaos Affecting Wrong Pods

**Prevention**:
```yaml
# Use precise selectors
selector:
  namespaces: [chaos-test]  # Explicit namespace
  labelSelectors:
    "chaos-ready": "true"    # Explicit opt-in label
    "app": "nginx"           # Specific app
```

**Recovery**:
```bash
# Immediately delete chaos
kubectl delete podchaos <name> -n chaos-test

# Check all running chaos experiments
kubectl get podchaos,networkchaos,stresschaos --all-namespaces
```

## Practical Use Cases

### 1. **Validate PodDisruptionBudgets**

**Test**: Do PDBs actually prevent cascading failures?

```bash
# Setup: Deploy app with PDB (minAvailable: 2 out of 3 replicas)
# Chaos: Kill pods one at a time
# Validate: At least 2 pods always remain running
# Result: Service maintains availability during rolling updates
```

### 2. **Test Horizontal Pod Autoscaler**

**Test**: Does HPA scale under load?

```bash
# Setup: Deploy app with HPA (target: 50% CPU)
# Chaos: CPU stress to trigger scaling
# Validate: HPA creates new pods when CPU >50%
# Result: Confirm autoscaling threshold and timing
```

### 3. **Verify StatefulSet Recovery**

**Test**: Do StatefulSets recover with correct identity?

```bash
# Setup: Deploy StatefulSet (Kafka, Cassandra, etc.)
# Chaos: Kill pod-1
# Validate: pod-1 recreated (not pod-4), same PVC attached
# Result: StatefulSet guarantees stable identity
```

### 4. **Test Circuit Breakers**

**Test**: Does circuit breaker open under failures?

```bash
# Setup: App with circuit breaker to backend
# Chaos: Network partition between app and backend
# Validate: Circuit breaker opens, fallback executes
# Result: App remains partially functional
```

### 5. **Validate Retry Logic**

**Test**: Does app retry transient failures?

```bash
# Setup: App with retry logic (3 retries with backoff)
# Chaos: 50% packet loss for 30s
# Validate: Requests succeed after retries
# Result: Confirm retry configuration works
```

### 6. **Test Multi-AZ Failover**

**Test**: Does app survive zone failure?

```bash
# Setup: Pods spread across zones (topology spread)
# Chaos: Network partition simulating zone failure
# Validate: Remaining zones handle traffic
# Result: Confirm multi-AZ architecture works
```

### 7. **Stress Test Rate Limiting**

**Test**: Does rate limiting protect backend?

```bash
# Setup: API gateway with rate limiting
# Chaos: CPU stress on backend
# Validate: Rate limiter prevents overload
# Result: Backend stays within capacity
```

### 8. **Test Graceful Degradation**

**Test**: Does app degrade gracefully under stress?

```bash
# Setup: App with multiple features
# Chaos: Memory stress (near OOM)
# Validate: Non-critical features disabled, core functions work
# Result: Confirm graceful degradation strategy
```

## Comparison: Chaos Mesh vs Alternatives

| Feature | Chaos Mesh | LitmusChaos | Gremlin |
|---------|------------|-------------|---------|
| **License** | Apache 2.0 (Open) | Apache 2.0 (Open) | Commercial |
| **Maturity** | CNCF Sandbox (2020) | CNCF Sandbox (2020) | Production (2016) |
| **Dashboard** | ✅ Built-in Web UI | ❌ Separate (Chaos Center) | ✅ SaaS UI |
| **Chaos Types** | 8 types (comprehensive) | 5 types | 10+ types |
| **Ease of Use** | Easy (GUI + YAML) | Moderate (YAML heavy) | Very Easy (SaaS) |
| **Kubernetes Native** | ✅ Yes | ✅ Yes | ✅ Yes + VMs/containers |
| **Scheduling** | ✅ Cron-based | ✅ Workflow-based | ✅ Advanced |
| **Cost** | Free | Free | $$$$ (paid) |
| **Best For** | **Homelab/learning** | CI/CD integration | Enterprise production |

**Recommendation**:
- **Chaos Mesh** for homelab/learning (built-in UI, easy setup)
- **LitmusChaos** for CI/CD pipelines (workflow-driven)
- **Gremlin** for enterprise with budget (commercial support)

## Learning Path

### Phase 1: Single Pod Failures (Start Here)
```bash
1. Deploy simple app (nginx)
2. Kill single pod
3. Observe recovery
Duration: 10 minutes
```

### Phase 2: Multi-Pod Scenarios
```bash
1. Deploy app with 3 replicas + PDB
2. Kill multiple pods (respect PDB)
3. Validate availability
Duration: 20 minutes
```

### Phase 3: Network Chaos
```bash
1. Deploy frontend + backend
2. Inject network latency
3. Test timeout handling
Duration: 30 minutes
```

### Phase 4: Resource Stress
```bash
1. Deploy app with CPU/memory limits
2. Stress test (CPU 100%)
3. Observe resource throttling
Duration: 20 minutes
```

### Phase 5: Complex Scenarios
```bash
1. Multi-tier app (3+ services)
2. Combine chaos (pod kill + network delay)
3. Test end-to-end resilience
Duration: 1 hour
```

### Phase 6: Production-Like Testing
```bash
1. Replicate production architecture
2. Run scheduled chaos experiments
3. Document findings and improvements
Duration: Ongoing
```

## Real-World Examples

### Example: Testing Prometheus HA

**Scenario**: Validate Prometheus high availability setup

```yaml
# Setup: 2 Prometheus replicas with Thanos
# Chaos: Kill one Prometheus pod
# Validate: Queries still work (second replica serves)
# Improvement: Add alerting for replica failures
```

### Example: Testing Ingress Controller

**Scenario**: Validate ingress failover

```yaml
# Setup: 2 nginx-ingress controllers
# Chaos: Kill one ingress pod
# Validate: Traffic routes to surviving controller
# Improvement: Add readiness probes, increase replicas
```

### Example: Testing Database Failover

**Scenario**: Validate PostgreSQL HA with CloudNativePG

```yaml
# Setup: 3-replica PostgreSQL cluster
# Chaos: Kill primary pod
# Validate: Failover to replica (<30s)
# Improvement: Tune failover detection time
```

## Uninstalling

### Remove Test Experiments

```bash
# Delete all chaos experiments
kubectl delete podchaos --all -n chaos-test
kubectl delete networkchaos --all -n chaos-test
kubectl delete stresschaos --all -n chaos-test

# Delete test namespace
kubectl delete namespace chaos-test
```

### Remove Chaos Mesh

```bash
kubectl delete -k k8s/optional/low-priority/chaos-mesh/
```

**Your 100/100 perfect score remains intact.**

## Learn More

- **Official Docs**: https://chaos-mesh.org/docs/
- **Interactive Tutorial**: https://chaos-mesh.org/interactive-tutorial
- **GitHub**: https://github.com/chaos-mesh/chaos-mesh
- **CNCF**: https://www.cncf.io/projects/chaos-mesh/
- **Community**: https://cloud-native.slack.com/messages/chaos-mesh
- **Chaos Engineering Book**: "Chaos Engineering" by Casey Rosenthal (O'Reilly)
- **Netflix Blog**: https://netflixtechblog.com/tagged/chaos-engineering

## Chaos Engineering Principles

Based on "Principles of Chaos Engineering" (principlesofchaos.org):

1. **Build a Hypothesis around Steady State Behavior**
   - Define metrics that indicate normal operation
   - Example: 99% requests succeed with <200ms latency

2. **Vary Real-World Events**
   - Simulate real failures (pod crashes, network issues)
   - Not artificial test cases

3. **Run Experiments in Production**
   - Staging ≠ Production (start safe, graduate to prod)
   - Chaos Mesh: Start in test namespace, eventually production

4. **Automate Experiments to Run Continuously**
   - Use schedulers (cron)
   - Integrate into CI/CD

5. **Minimize Blast Radius**
   - Use selectors, PDBs, short durations
   - Chaos Mesh safety features enable this

---

**Remember**: Chaos Mesh is a **learning and validation tool**. Your cluster is **already perfect** at 100/100 without it. Use this to:
- **Learn** Kubernetes resilience patterns
- **Validate** your PDBs, limits, and policies actually work
- **Gain confidence** in your cluster's reliability
- **Improve** by discovering weaknesses in controlled tests

**Start small, learn continuously, break things on purpose (safely).**
