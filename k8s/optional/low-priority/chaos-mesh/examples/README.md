# Chaos Mesh Examples

This directory contains practical chaos engineering experiments to test Kubernetes cluster resilience.

## Quick Start

### 1. Create Test Namespace

```bash
kubectl create namespace chaos-test
```

### 2. Choose an Experiment

| Experiment | Purpose | Difficulty | Duration |
|------------|---------|------------|----------|
| `pod-kill-experiment.yaml` | Test PodDisruptionBudgets | Beginner | 10 min |
| `network-chaos-experiment.yaml` | Test network resilience | Intermediate | 20 min |
| `cpu-stress-experiment.yaml` | Test resource limits & HPA | Intermediate | 30 min |

### 3. Run an Experiment

```bash
# Example: Test PodDisruptionBudget
kubectl apply -f pod-kill-experiment.yaml

# Watch the chaos
kubectl get pods -n chaos-test -w
```

### 4. Clean Up

```bash
# Delete chaos experiments
kubectl delete podchaos,networkchaos,stresschaos --all -n chaos-test

# Delete test applications
kubectl delete deployment,service,pdb --all -n chaos-test

# Optional: Delete namespace
kubectl delete namespace chaos-test
```

## Experiments Overview

### Pod Kill Experiment (`pod-kill-experiment.yaml`)

**What it tests:**
- PodDisruptionBudgets prevent cascading failures
- ReplicaSets recreate terminated pods
- Services remain available during pod restarts

**Components:**
- nginx Deployment (3 replicas)
- PodDisruptionBudget (minAvailable: 1)
- PodChaos experiments (kill one, kill all)

**Expected outcome:**
- Pods are killed one at a time
- At least 1 pod always remains running (PDB enforced)
- Service remains accessible throughout

**Commands:**
```bash
# Deploy application
kubectl apply -f pod-kill-experiment.yaml

# Test service availability during chaos
kubectl run curl-test --rm -it --image=curlimages/curl --restart=Never \
  -- sh -c 'while true; do curl -s http://nginx.chaos-test && echo " - OK"; sleep 1; done'
```

---

### Network Chaos Experiment (`network-chaos-experiment.yaml`)

**What it tests:**
- Applications handle network latency gracefully
- Retry logic works for packet loss
- Circuit breakers open during partitions
- Timeout configurations are appropriate

**Components:**
- Frontend and Backend Deployments
- NetworkChaos experiments:
  - Delay (100ms latency)
  - Loss (10% packet loss)
  - Corrupt (5% corruption)
  - Bandwidth (1Mbps limit)
  - Partition (split-brain)
  - Duplicate (10% duplication)

**Expected outcome:**
- Services degrade but remain functional
- Requests succeed with increased latency
- Retries handle transient failures

**Commands:**
```bash
# Deploy applications
kubectl apply -f network-chaos-experiment.yaml

# Monitor frontend logs
kubectl logs -n chaos-test -l app=frontend -f

# Test latency from outside
kubectl run curl --rm -it --image=curlimages/curl --restart=Never \
  -- time curl http://backend.chaos-test
```

---

### CPU Stress Experiment (`cpu-stress-experiment.yaml`)

**What it tests:**
- CPU limits prevent resource exhaustion
- Horizontal Pod Autoscaler scales correctly
- OOMKiller behavior under memory stress
- Resource throttling vs killing

**Components:**
- Application Deployment with resource limits
- HorizontalPodAutoscaler (2-5 replicas)
- StressChaos experiments:
  - CPU stress (200% load)
  - Memory stress (100Mi)
  - Combined stress
  - OOMKiller trigger (200Mi)
  - HPA trigger (sustained load)

**Expected outcome:**
- CPU usage hits limit, pod is throttled (not killed)
- Memory exceeding limit triggers OOMKiller
- HPA scales up when CPU >50%

**Commands:**
```bash
# Deploy application
kubectl apply -f cpu-stress-experiment.yaml

# Monitor resource usage
kubectl top pods -n chaos-test --watch

# Watch HPA scaling
kubectl get hpa -n chaos-test -w
```

## Safety Guidelines

### Always Follow These Rules:

1. **Use dedicated test namespace**
   ```bash
   kubectl create namespace chaos-test
   ```

2. **Label pods explicitly**
   ```yaml
   labels:
     chaos-ready: "true"  # Opt-in to chaos
   ```

3. **Set short durations**
   ```yaml
   duration: "30s"  # Start small
   ```

4. **Monitor actively**
   ```bash
   kubectl get pods -n chaos-test -w
   ```

5. **Clean up after experiments**
   ```bash
   kubectl delete podchaos --all -n chaos-test
   ```

### Never Do This:

- Run chaos in `default`, `kube-system`, or production namespaces
- Set durations >5 minutes without monitoring
- Target pods without `chaos-ready: true` label
- Run multiple experiments simultaneously (when learning)
- Forget to clean up chaos experiments

## Progression Path

### Phase 1: Single Pod (Start Here)
```bash
1. pod-kill-experiment.yaml (one pod)
2. Observe recovery
3. Verify PDB enforcement
Duration: 10 minutes
```

### Phase 2: Network Issues
```bash
1. network-chaos-experiment.yaml (delay)
2. Observe latency increase
3. Test with packet loss
Duration: 20 minutes
```

### Phase 3: Resource Stress
```bash
1. cpu-stress-experiment.yaml (CPU)
2. Watch HPA scale
3. Test OOMKiller
Duration: 30 minutes
```

### Phase 4: Combined Chaos
```bash
1. Run pod-kill + network-delay simultaneously
2. Test real-world failure scenarios
3. Document findings
Duration: 1 hour
```

## Troubleshooting Experiments

### Chaos Not Starting

**Problem:** Experiment created but no chaos happening

**Solutions:**
```bash
# Check selector matches pods
kubectl get pods -n chaos-test -l chaos-ready=true

# Check chaos status
kubectl describe podchaos <name> -n chaos-test

# Check controller logs
kubectl logs -n chaos-mesh -l app.kubernetes.io/component=controller-manager
```

### Chaos Not Stopping

**Problem:** Chaos continues after duration

**Solutions:**
```bash
# Delete chaos experiment
kubectl delete podchaos <name> -n chaos-test

# Force delete if stuck
kubectl patch podchaos <name> -n chaos-test \
  -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete podchaos <name> -n chaos-test --force
```

### Pods Being Affected Unexpectedly

**Problem:** Wrong pods are affected by chaos

**Solutions:**
```bash
# Use more specific selectors
selector:
  namespaces: [chaos-test]      # Explicit namespace
  labelSelectors:
    "chaos-ready": "true"        # Explicit opt-in
    "app": "specific-app"        # Specific application

# Check which pods match selector
kubectl get pods -n chaos-test -l chaos-ready=true,app=specific-app
```

## Advanced Testing Ideas

### Test Database Failover
```yaml
# Setup: PostgreSQL with CloudNativePG (3 replicas)
# Chaos: Kill primary pod
# Validate: Failover to replica <30s
# Improvement: Tune failover detection time
```

### Test Service Mesh Retries
```yaml
# Setup: Istio/Linkerd with retry policies
# Chaos: 50% packet loss
# Validate: Retries succeed, circuit breaker opens
# Improvement: Tune retry backoff
```

### Test Cluster Autoscaler
```yaml
# Setup: Cluster autoscaler enabled
# Chaos: CPU stress on all nodes (trigger node pressure)
# Validate: New nodes added automatically
# Improvement: Adjust scaling thresholds
```

### Test Multi-Zone Resilience
```yaml
# Setup: Pods spread across availability zones
# Chaos: Network partition simulating zone failure
# Validate: Remaining zones handle traffic
# Improvement: Adjust topology spread constraints
```

## Metrics to Monitor

During chaos experiments, monitor these metrics in Prometheus/Grafana:

### Application Metrics
- `http_request_duration_seconds` - Latency (p50, p95, p99)
- `http_requests_total` - Request rate
- `http_request_errors_total` - Error rate
- `process_cpu_seconds_total` - CPU usage
- `process_resident_memory_bytes` - Memory usage

### Kubernetes Metrics
- `kube_pod_status_phase` - Pod health
- `kube_pod_container_status_restarts_total` - Restart count
- `kube_horizontalpodautoscaler_status_current_replicas` - HPA state
- `kube_poddisruptionbudget_status_current_healthy` - PDB state

### Chaos Mesh Metrics
- `chaos_mesh_experiments_total` - Total experiments
- `chaos_mesh_experiment_status` - Experiment status
- `chaos_mesh_daemon_health` - Daemon health

## Learning Outcomes

After completing these experiments, you will understand:

- ✅ How PodDisruptionBudgets protect service availability
- ✅ How Kubernetes recovers from pod failures automatically
- ✅ How network issues affect distributed systems
- ✅ How retry logic and circuit breakers work in practice
- ✅ How resource limits prevent resource exhaustion
- ✅ How HPA scales based on resource utilization
- ✅ How to test chaos safely in a controlled environment
- ✅ How to monitor and observe chaos experiment impact

## References

- **Chaos Mesh Docs**: https://chaos-mesh.org/docs/
- **Chaos Engineering Principles**: https://principlesofchaos.org/
- **Kubernetes Patterns**: https://k8s-patterns.io/
- **SRE Book (Google)**: https://sre.google/books/

---

**Remember**: These experiments are for **learning and validation** in test environments. Always start small, monitor actively, and clean up after experiments.
