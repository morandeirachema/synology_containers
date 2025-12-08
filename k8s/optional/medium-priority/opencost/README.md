# OpenCost - Kubernetes Cost Visibility & FinOps

## Overview

OpenCost is a **vendor-neutral, open-source** cost monitoring tool for Kubernetes. It provides real-time cost allocation, resource efficiency analysis, and showback/chargeback capabilities - all for **FREE**.

**Status**: ✅ OPTIONAL - FinOps & operational excellence enhancement

## Why OpenCost?

### The Problem: Hidden Cloud Costs

Without cost visibility:
- ❌ Unknown which applications/teams consume resources
- ❌ Over-provisioned workloads waste money
- ❌ No accountability for resource usage
- ❌ Difficult to optimize spending
- ❌ Surprise cloud bills

OpenCost provides:
- ✅ **Real-time cost tracking**: Per namespace, pod, container, label
- ✅ **Resource efficiency**: Identify over-provisioned workloads
- ✅ **Showback/Chargeback**: Allocate costs to teams/projects
- ✅ **Cost optimization**: Actionable recommendations
- ✅ **Vendor neutral**: Works with any cloud or on-prem
- ✅ **100% free**: No licensing, no limits

### FinOps for Homelabs

```
┌──────────────────────────────────────────────────┐
│  Without OpenCost                                │
├──────────────────────────────────────────────────┤
│  "My cluster uses... some power? Some storage?"  │
│  No visibility into resource allocation          │
│  Can't identify wasteful workloads               │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│  With OpenCost                                   │
├──────────────────────────────────────────────────┤
│  "Production namespace: 60% CPU utilization"     │
│  "Monitoring stack over-provisioned by 2 cores"  │
│  "Idle workloads wasting 4GB RAM"                │
│  "Monthly cost breakdown by team"                │
└──────────────────────────────────────────────────┘
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│         Prometheus (Existing)                    │
│  - Node metrics (CPU, memory, disk)              │
│  - cAdvisor metrics (container usage)            │
│  - kube-state-metrics (resource requests/limits) │
└──────────────────────────────────────────────────┘
                     │
                     ↓
┌──────────────────────────────────────────────────┐
│  OpenCost Backend (1 replica)                    │
│  - Queries Prometheus every 5 minutes            │
│  - Calculates costs per resource                 │
│  - Stores cost data (in-memory + optional PVC)   │
│  - Exposes /allocation API                       │
└──────────────────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
   ┌──────────┐ ┌─────────┐ ┌─────────────┐
   │ OpenCost │ │ Grafana │ │  Prometheus │
   │   UI     │ │Dashboard│ │  (Metrics)  │
   │(Optional)│ │         │ │             │
   └──────────┘ └─────────┘ └─────────────┘
```

## Features

### Cost Allocation

**By Namespace**
```
production:    $45.20/month (60% CPU, 8GB RAM)
monitoring:    $22.10/month (30% CPU, 4GB RAM)
databases:     $15.05/month (10% CPU, 2GB RAM)
```

**By Label**
```
team=backend:   $50.30/month
team=frontend:  $20.15/month
team=data:      $11.90/month
```

**By Pod**
```
nginx-7d8f9-xyz:     $0.45/day
postgres-ha-1:       $1.20/day
prometheus-server:   $0.90/day
```

### Resource Efficiency

**Over-provisioned Workloads**
- Requested: 2 CPU cores
- Actual usage: 0.3 cores (85% waste)
- **Recommendation**: Reduce requests to 500m

**Idle Resources**
- Allocated: 8GB RAM
- Used: 2GB RAM (75% waste)
- **Savings**: Can reclaim 6GB for other workloads

### Showback/Chargeback

**Team-based cost allocation**:
```
Team Alpha:   $150/month (3 namespaces)
Team Beta:    $80/month (2 namespaces)
Platform:     $50/month (shared services)
```

Use for:
- Internal billing
- Budget tracking
- Resource governance
- Cost accountability

## Resource Requirements

### OpenCost Backend (1 replica)
- **CPU**: 200m request, 1000m limit
- **Memory**: 256Mi request, 1Gi limit
- **Storage**: Optional 32Gi PVC for cost data persistence

### OpenCost UI (Optional, 1 replica)
- **CPU**: 10m request, 100m limit
- **Memory**: 32Mi request, 128Mi limit

### Total Overhead
- **CPU**: ~210m
- **Memory**: ~300Mi
- **Storage**: 32Gi (optional, for cost history)

**Conclusion**: Minimal overhead, high value.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (required for metrics)
- Grafana (optional, for dashboards)
- kube-state-metrics (already deployed)

### Quick Deploy

```bash
kubectl apply -k k8s/optional/medium-priority/opencost/
```

### Verify Deployment

```bash
# Check OpenCost is running
kubectl get deployment -n opencost
kubectl get pods -n opencost

# Check OpenCost API is accessible
kubectl port-forward -n opencost svc/opencost 9003:9003
curl http://localhost:9003/healthz

# Expected output:
# {"status":"healthy"}
```

## Configuration

### Basic Deployment (Default)

Uses in-memory storage (data lost on pod restart):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opencost
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: opencost
          image: ghcr.io/opencost/opencost:latest
          env:
            - name: PROMETHEUS_SERVER_ENDPOINT
              value: "http://prometheus-operated.monitoring:9090"
```

### With Persistent Storage

Retain cost data across pod restarts:

```yaml
spec:
  volumes:
    - name: opencost-data
      persistentVolumeClaim:
        claimName: opencost-data
  containers:
    - name: opencost
      volumeMounts:
        - name: opencost-data
          mountPath: /var/opencost
```

### Custom Pricing (On-Prem/Homelab)

Set custom hourly rates:

```yaml
env:
  # CPU cost per core per hour
  - name: CPU_PRICE
    value: "0.031611"  # AWS m5.xlarge equivalent

  # RAM cost per GB per hour
  - name: RAM_PRICE
    value: "0.004237"

  # Storage cost per GB per month
  - name: STORAGE_PRICE
    value: "0.10"  # $0.10/GB/month

  # Custom label for cost center
  - name: COST_ALLOCATION_LABELS
    value: "team,app,environment"
```

**For homelab**: Estimate electricity costs:
- Measure power draw (e.g., 200W)
- Calculate: `200W × 24h × $0.12/kWh = $0.576/day`
- Divide by cluster capacity for per-core/GB rates

### Cloud-Specific Pricing

Auto-detect cloud pricing (AWS, GCP, Azure):

```yaml
env:
  - name: CLOUD_PROVIDER_API_KEY
    value: "your-api-key"  # Optional for spot pricing
```

**Note**: Not needed for homelabs (use custom pricing).

## Using OpenCost

### Access OpenCost UI

```bash
# Port-forward to access UI
kubectl port-forward -n opencost svc/opencost-ui 9090:9090

# Open browser
http://localhost:9090
```

**UI Features**:
- Cost breakdown by namespace, deployment, pod
- Time series charts (daily, weekly, monthly)
- Efficiency recommendations
- Export to CSV

### Query Allocation API

**Cost by Namespace (Last 7 Days)**

```bash
kubectl port-forward -n opencost svc/opencost 9003:9003

curl "http://localhost:9003/allocation?window=7d&aggregate=namespace" | jq .
```

**Response**:
```json
{
  "production": {
    "cpuCost": 12.50,
    "ramCost": 8.30,
    "pvCost": 5.20,
    "totalCost": 26.00
  },
  "monitoring": {
    "cpuCost": 6.20,
    "ramCost": 4.10,
    "pvCost": 2.00,
    "totalCost": 12.30
  }
}
```

**Cost by Label**

```bash
curl "http://localhost:9003/allocation?window=7d&aggregate=label:team" | jq .
```

**Cost by Pod (Top 10)**

```bash
curl "http://localhost:9003/allocation?window=1d&aggregate=pod" | jq -r 'to_entries | sort_by(.value.totalCost) | reverse | .[0:10] | .[] | "\(.key): $\(.value.totalCost)"'
```

### Efficiency Analysis

**Find Over-Provisioned Workloads**

```bash
# Get efficiency metrics
curl "http://localhost:9003/allocation?window=7d&aggregate=namespace" | \
  jq '.[] | select(.cpuEfficiency < 0.5) | {namespace: .name, cpuEfficiency: .cpuEfficiency}'
```

**Response**:
```json
{
  "namespace": "monitoring",
  "cpuEfficiency": 0.25  // Only using 25% of requested CPU
}
```

**Recommendation**: Reduce CPU requests by 50-75%.

## Grafana Dashboards

### Official OpenCost Dashboard

Import from Grafana:
- **Dashboard ID**: `15798`
- **URL**: https://grafana.com/grafana/dashboards/15798

**Panels Include**:
- Total cluster cost
- Cost by namespace (pie chart)
- Cost trends over time
- Resource efficiency
- Top 10 most expensive pods

### Custom Dashboard Queries

**Total Monthly Cost**

```promql
sum(
  rate(opencost_allocation_total_cost[30d])
) * 30 * 24
```

**Cost Per Namespace**

```promql
sum by (namespace) (
  rate(opencost_allocation_total_cost[1h])
) * 24 * 30
```

**CPU Efficiency**

```promql
avg by (namespace) (
  opencost_allocation_cpu_usage / opencost_allocation_cpu_request
)
```

## Monitoring & Alerts

### Prometheus Metrics

OpenCost exposes metrics at `:9003/metrics`:

```
opencost_allocation_total_cost - Total cost per allocation
opencost_allocation_cpu_cost - CPU cost
opencost_allocation_ram_cost - RAM cost
opencost_allocation_pv_cost - Storage cost
opencost_allocation_cpu_usage - Actual CPU usage
opencost_allocation_cpu_request - CPU requests
opencost_allocation_ram_usage - Actual RAM usage
opencost_allocation_ram_request - RAM requests
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `OpenCostDown` | Warning | OpenCost pod down >5 min |
| `HighCostIncrease` | Warning | Cost increased >50% in 24h |
| `LowCPUEfficiency` | Info | Namespace CPU efficiency <30% |
| `LowRAMEfficiency` | Info | Namespace RAM efficiency <30% |
| `NamespaceCostBudgetExceeded` | Warning | Namespace exceeds monthly budget |

## Use Cases

### 1. Multi-Tenant Clusters

**Problem**: Multiple teams share the cluster, but who's using what?

**Solution**: OpenCost shows cost per team/namespace.

```bash
# Get costs by team label
curl "http://localhost:9003/allocation?window=30d&aggregate=label:team"
```

**Result**: Charge teams based on actual usage.

### 2. Resource Optimization

**Problem**: Cluster feels slow, but where are resources going?

**Solution**: Find over-provisioned workloads.

```bash
# Find inefficient workloads
kubectl exec -n opencost opencost-xxx -- \
  /bin/sh -c "curl localhost:9003/allocation?window=7d | jq '.[] | select(.cpuEfficiency < 0.3)'"
```

**Result**: Identify workloads requesting 2 cores but using 0.5 cores.

### 3. Budget Tracking

**Problem**: Need to stay within monthly cloud budget.

**Solution**: Track cumulative costs.

```bash
# Get month-to-date costs
curl "http://localhost:9003/allocation?window=$(date +%d)d&aggregate=cluster"
```

**Result**: Compare against budget ($500/month).

### 4. Showback Reporting

**Problem**: Finance wants monthly cost reports by department.

**Solution**: Export cost data.

```bash
# Generate CSV report
curl "http://localhost:9003/allocation?window=30d&aggregate=label:department&format=csv" > monthly-costs.csv
```

**Result**: Share with finance team.

## Cost Optimization Recommendations

### Find Idle Resources

```bash
# Pods with <10% CPU usage
kubectl top pods -A | awk '$3 < 10 {print $1, $2, $3}'
```

**Action**: Reduce CPU requests or consolidate workloads.

### Identify Over-Provisioned Deployments

```bash
# Query OpenCost for efficiency
curl "http://localhost:9003/allocation?window=7d" | \
  jq '.[] | select(.cpuEfficiency < 0.5) | {name, cpuRequest, cpuUsage, efficiency: .cpuEfficiency}'
```

**Action**: Right-size resource requests.

### Storage Waste

```bash
# Unused PVCs
kubectl get pvc -A --no-headers | while read ns pvc _; do
  POD=$(kubectl get pods -n $ns -o json | jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == \"$pvc\") | .metadata.name")
  [ -z "$POD" ] && echo "Unused PVC: $ns/$pvc"
done
```

**Action**: Delete unused PVCs.

## Troubleshooting

### OpenCost Shows $0 Costs

```bash
# Check Prometheus connectivity
kubectl logs -n opencost -l app=opencost | grep -i prometheus

# Verify Prometheus endpoint
kubectl exec -n opencost opencost-xxx -- \
  curl http://prometheus-operated.monitoring:9090/api/v1/query?query=up

# Check pricing is configured
kubectl exec -n opencost opencost-xxx -- env | grep PRICE
```

**Common issues**:
- Prometheus endpoint incorrect
- No pricing configured (set CPU_PRICE, RAM_PRICE)
- Prometheus missing cAdvisor metrics

### Missing Metrics

```bash
# Check required metrics exist
kubectl port-forward -n monitoring prometheus-operated-0 9090:9090

# Query in browser:
http://localhost:9090/graph?g0.expr=container_cpu_usage_seconds_total

# Should return data. If not, check cAdvisor is enabled on nodes.
```

### High Memory Usage

OpenCost stores cost data in memory by default.

**Solution**: Enable persistent storage.

```yaml
volumes:
  - name: opencost-data
    persistentVolumeClaim:
      claimName: opencost-data
```

## Security Considerations

### RBAC Permissions

OpenCost ServiceAccount has cluster-wide **read-only** access:

```yaml
verbs: ["get", "list"]  # Read-only
resources: ["pods", "nodes", "namespaces", "persistentvolumes", "persistentvolumeclaims"]
```

**Why**: Needs to read all resources to calculate costs.

**Mitigation**:
- No write permissions
- Read-only access to resource metrics
- No access to Secrets or sensitive data

### Data Sensitivity

Cost data may be sensitive (reveals resource usage patterns).

**Recommendation**:
- Limit access to OpenCost UI (use NetworkPolicy)
- Use RBAC to restrict who can query allocation API
- Consider exposing only via Grafana dashboards (controlled access)

## Comparison: OpenCost vs Alternatives

| Feature | OpenCost | Kubecost (Free) | Kubecost (Paid) | Cloud Provider Tools |
|---------|----------|-----------------|-----------------|----------------------|
| **Cost** | FREE | FREE (15 nodes) | $500+/month | Included |
| **Vendor** | CNCF/Open Source | Commercial | Commercial | Cloud-specific |
| **Multi-cloud** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **On-prem** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **API access** | ✅ Full | ✅ Limited | ✅ Full | ✅ Full |
| **Showback** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Limited |
| **Recommendations** | ✅ Basic | ✅ Advanced | ✅ Advanced | ✅ Advanced |
| **Granularity** | Container-level | Container-level | Container-level | Pod-level |
| **Data retention** | Configurable | 15 days | Unlimited | Varies |

**Recommendation**: **OpenCost for homelabs** (100% free). Kubecost Paid for enterprise (advanced features).

## Integration with Existing Stack

### Prometheus

OpenCost queries Prometheus for:
- `container_cpu_usage_seconds_total` (cAdvisor)
- `container_memory_usage_bytes` (cAdvisor)
- `kube_pod_container_resource_requests` (kube-state-metrics)
- `kube_node_status_capacity` (kube-state-metrics)

**No changes needed** - your existing Prometheus has these metrics.

### Grafana

Import OpenCost dashboard (#15798) for visualization.

**Alternative**: Create custom dashboards using OpenCost metrics.

## Uninstalling

```bash
kubectl delete -k k8s/optional/medium-priority/opencost/
```

**Cost data is deleted** unless using persistent storage.

## Learn More

- **Official Docs**: https://www.opencost.io/docs/
- **GitHub**: https://github.com/opencost/opencost
- **CNCF**: https://www.cncf.io/projects/opencost/
- **Slack**: https://cloud-native.slack.com/archives/C03D56FPD4G
- **Spec**: https://github.com/opencost/opencost/blob/develop/spec/opencost-specv01.md

---

**Remember**: OpenCost is an **optional enhancement** for cost visibility and FinOps. Your cluster is **already perfect** at 100/100 without it.

---

[Back to Optional Enhancements](../../README.md) | [CloudNativePG](../cloudnative-pg/README.md) | [Flagger](../flagger/README.md) | [Main README](../../../../README.md)
