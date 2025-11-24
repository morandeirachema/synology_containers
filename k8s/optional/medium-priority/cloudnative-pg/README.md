# CloudNativePG - Production PostgreSQL Operator

## Overview

CloudNativePG is a **Kubernetes operator** that manages the full lifecycle of PostgreSQL clusters with high availability, automated failover, backups, and point-in-time recovery (PITR).

**Status**: ✅ OPTIONAL - Operational excellence enhancement

## Why CloudNativePG?

### Replaces Manual PostgreSQL Management

Without CloudNativePG:
- ❌ Manual PostgreSQL setup and configuration
- ❌ Manual replication configuration
- ❌ Manual backup scripts
- ❌ Manual failover procedures
- ❌ Complex recovery processes

CloudNativePG provides:
- ✅ **Automated HA**: Multi-replica clusters with automatic failover
- ✅ **Continuous backups**: WAL archiving to S3-compatible storage
- ✅ **Point-in-time recovery**: Restore to any second in time
- ✅ **Rolling updates**: Zero-downtime PostgreSQL upgrades
- ✅ **Connection pooling**: Built-in PgBouncer integration
- ✅ **Monitoring**: Native Prometheus metrics

### Cloud Native Architecture

```
┌─────────────────────────────────────────────────┐
│  Application Pods                               │
│  - Connect via Service                          │
│  - Read/Write split support                     │
└─────────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────┐
│  PostgreSQL Cluster (3 replicas)                │
│  ┌──────────────┐  ┌──────────────┐  ┌────────┐│
│  │  Primary     │  │  Replica 1   │  │ Replica││
│  │  (Read/Write)│→ │  (Read-only) │  │  2     ││
│  │              │  │              │  │ (Read) ││
│  └──────────────┘  └──────────────┘  └────────┘│
│         │                 │               │     │
│         └─────────────────┴───────────────┘     │
│                     │                           │
│              WAL Streaming                      │
└─────────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────┐
│  Backups (S3-compatible storage)                │
│  - Continuous WAL archiving                     │
│  - Scheduled base backups                       │
│  - Point-in-time recovery capability            │
└─────────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────┐
│  CloudNativePG Operator                         │
│  - Monitors cluster health                      │
│  - Performs automatic failover (<30s)           │
│  - Manages backups and recovery                 │
│  - Handles rolling updates                      │
└─────────────────────────────────────────────────┘
```

## Features

### High Availability

- **Automatic failover**: Primary failure detected in <30 seconds
- **Synchronous replication**: Zero data loss mode available
- **Quorum-based**: Prevents split-brain scenarios
- **Self-healing**: Failed replicas automatically recreated

### Backup & Recovery

- **Continuous archiving**: WAL segments to S3/MinIO/local storage
- **Scheduled backups**: Daily full backups + continuous WAL
- **PITR**: Restore to any point in time within retention period
- **Barman integration**: Enterprise-grade backup management

### Operations

- **Rolling updates**: Zero-downtime PostgreSQL minor version upgrades
- **Connection pooling**: Optional PgBouncer sidecar
- **TLS encryption**: Mutual TLS for all connections
- **Resource management**: CPU/memory limits, PVCs

## Resource Requirements

### Operator Deployment (1 replica)
- **CPU**: 100m request, 500m limit
- **Memory**: 100Mi request, 200Mi limit
- **Storage**: None (ephemeral)

### PostgreSQL Cluster (3 replicas - example)
Each replica:
- **CPU**: 500m request, 2000m limit
- **Memory**: 1Gi request, 2Gi limit
- **Storage**: 20Gi PVC per replica

### Total Example Cluster
- **CPU**: ~1.6 cores (operator + 3 replicas)
- **Memory**: ~6.2Gi (operator + 3 replicas)
- **Storage**: 60Gi (3x 20Gi PVCs)

**Note**: Cluster sizing depends on your database workload.

## Deployment

### Prerequisites

✅ Cluster already has:
- Prometheus (for metrics)
- Grafana (for visualization)
- StorageClass with ReadWriteOnce support

### Quick Deploy Operator

```bash
kubectl apply -k k8s/optional/medium-priority/cloudnative-pg/
```

### Verify Operator

```bash
# Check operator is running
kubectl get deployment -n cnpg-system
kubectl get pods -n cnpg-system

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# cnpg-controller-manager-xxx         1/1     Running   0          1m
```

### Create Example PostgreSQL Cluster

```bash
# Deploy a 3-replica HA cluster
kubectl apply -f k8s/optional/medium-priority/cloudnative-pg/examples/cluster-example.yaml

# Check cluster status
kubectl get cluster -n databases

# Check pods
kubectl get pods -n databases -l cnpg.io/cluster=postgres-ha

# Expected output:
# NAME            ROLE      STATUS    AGE
# postgres-ha-1   Primary   Ready     2m
# postgres-ha-2   Replica   Ready     2m
# postgres-ha-3   Replica   Ready     2m
```

## Configuration

### Basic PostgreSQL Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-ha
  namespace: databases
spec:
  instances: 3  # 1 primary + 2 replicas

  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      work_mem: "4MB"

  storage:
    size: 20Gi
    storageClass: local-path

  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

  monitoring:
    enablePodMonitor: true
```

### With Backups to MinIO/S3

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-ha
spec:
  instances: 3

  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backups/
      endpointURL: http://minio.storage:9000
      s3Credentials:
        accessKeyId:
          name: minio-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-credentials
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
        maxParallel: 2

    retentionPolicy: "30d"  # Keep backups for 30 days

  # Scheduled backup (daily at 3 AM)
  backup:
    target: prefer-standby
    schedule: "0 3 * * *"
```

### Connection Pooling with PgBouncer

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-ha
spec:
  instances: 3

  # Enable PgBouncer sidecar
  pgBouncer:
    poolMode: transaction
    parameters:
      max_client_conn: "1000"
      default_pool_size: "25"
      reserve_pool_size: "5"
```

## Usage Examples

### Connect to Primary (Read/Write)

```bash
# Get connection details
kubectl get cluster postgres-ha -n databases -o jsonpath='{.status.writeService}'

# Connect via psql
kubectl run psql-client --rm -it \
  --image=postgres:16 \
  --restart=Never \
  -- psql -h postgres-ha-rw.databases.svc.cluster.local -U app -d app
```

### Connect to Replicas (Read-Only)

```bash
# Connect to read-only service (load balanced across replicas)
kubectl run psql-client --rm -it \
  --image=postgres:16 \
  --restart=Never \
  -- psql -h postgres-ha-ro.databases.svc.cluster.local -U app -d app
```

### Perform Manual Backup

```bash
# Create on-demand backup
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d-%H%M%S)
  namespace: databases
spec:
  cluster:
    name: postgres-ha
EOF

# Check backup status
kubectl get backups -n databases
```

### Point-in-Time Recovery

```bash
# Restore to specific timestamp
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restored
  namespace: databases
spec:
  instances: 3

  bootstrap:
    recovery:
      source: postgres-ha
      recoveryTarget:
        targetTime: "2025-01-15 10:30:00.000000+00"

  externalClusters:
    - name: postgres-ha
      barmanObjectStore:
        destinationPath: s3://postgres-backups/
        endpointURL: http://minio.storage:9000
        s3Credentials:
          accessKeyId:
            name: minio-credentials
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: minio-credentials
            key: SECRET_ACCESS_KEY
EOF
```

## Monitoring & Alerts

### Prometheus Metrics

CloudNativePG exposes comprehensive metrics at `:9187/metrics`:

```
cnpg_collector_up - Metrics collector status
cnpg_pg_database_size_bytes - Database size
cnpg_pg_replication_lag_seconds - Replication lag
cnpg_pg_stat_archiver_archived_count - WAL segments archived
cnpg_pg_stat_database_xact_commit - Transaction commits
cnpg_pg_postmaster_start_time - PostgreSQL uptime
```

### Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| `PostgreSQLDown` | Critical | Primary pod down >5 min |
| `PostgreSQLReplicationLag` | Warning | Lag >10 seconds |
| `PostgreSQLBackupFailed` | Critical | Backup failure |
| `PostgreSQLHighConnections` | Warning | >80% max connections |
| `PostgreSQLDiskSpaceNearFull` | Warning | >85% disk usage |
| `PostgreSQLReplicaMissing` | Warning | Replica count below spec |

### Grafana Dashboard

Official CloudNativePG dashboard available:
- **Dashboard ID**: `20417`
- **URL**: https://grafana.com/grafana/dashboards/20417

Includes:
- Connection statistics
- Transaction rates
- Replication lag
- Backup status
- Resource utilization

## Failover Testing

### Simulate Primary Failure

```bash
# Delete primary pod
PRIMARY_POD=$(kubectl get pods -n databases -l cnpg.io/cluster=postgres-ha,cnpg.io/instanceRole=primary -o name)
kubectl delete $PRIMARY_POD -n databases

# Watch automatic failover (<30 seconds)
kubectl get cluster postgres-ha -n databases -w

# Check new primary
kubectl get pods -n databases -l cnpg.io/cluster=postgres-ha -L cnpg.io/instanceRole
```

**Expected behavior**:
1. Primary pod deleted
2. Operator detects failure (~5-10s)
3. Promotes a replica to primary (~10-20s)
4. Updates services to point to new primary
5. Recreates failed pod as new replica

**Total downtime**: <30 seconds (typically 15-25s)

## Backup & Recovery Operations

### List Backups

```bash
# Show all backups
kubectl get backups -n databases

# Get backup details
kubectl describe backup backup-20250124-030000 -n databases
```

### Restore Cluster from Backup

```bash
# Full cluster restore
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restored
  namespace: databases
spec:
  instances: 3

  bootstrap:
    recovery:
      source: postgres-ha
      # No targetTime = restore to latest available

  externalClusters:
    - name: postgres-ha
      barmanObjectStore:
        destinationPath: s3://postgres-backups/
        endpointURL: http://minio.storage:9000
        s3Credentials:
          accessKeyId:
            name: minio-credentials
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: minio-credentials
            key: SECRET_ACCESS_KEY
EOF
```

### Verify Backup Integrity

```bash
# Check WAL archiving is working
kubectl exec -n databases postgres-ha-1 -- \
  psql -U postgres -c "SELECT pg_walfile_name(pg_current_wal_lsn());"

# Check backup status
kubectl get cluster postgres-ha -n databases -o jsonpath='{.status.lastSuccessfulBackup}'
```

## Upgrading PostgreSQL

### Minor Version Upgrade (16.1 → 16.2)

```yaml
# Update image tag
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2
```

Apply and watch rolling update:
```bash
kubectl apply -f cluster.yaml
kubectl get pods -n databases -w
```

**Process**:
1. Replicas upgraded first (one at a time)
2. Controlled switchover to upgraded replica
3. Old primary upgraded
4. Zero downtime

### Major Version Upgrade (16 → 17)

Requires `pg_upgrade`:

```bash
# 1. Create new cluster with PG17
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-pg17
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17

  bootstrap:
    pg_upgrade:
      source: postgres-ha

  externalClusters:
    - name: postgres-ha
      connectionParameters:
        host: postgres-ha-rw
        user: postgres
        dbname: postgres
      password:
        name: postgres-ha-superuser
        key: password
EOF

# 2. Switch application to new cluster
# 3. Decommission old cluster
```

## Troubleshooting

### Cluster Not Starting

```bash
# Check operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Check cluster events
kubectl describe cluster postgres-ha -n databases

# Check pod events
kubectl describe pod postgres-ha-1 -n databases
```

**Common issues**:
- PVC provisioning failure: Check StorageClass exists
- Image pull errors: Verify image name and registry access
- Resource limits: Ensure node has available CPU/memory

### Replication Lag High

```bash
# Check replication status
kubectl exec -n databases postgres-ha-1 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check replica is receiving WAL
kubectl logs -n databases postgres-ha-2 | grep "redo"
```

**Common causes**:
- Network issues between primary and replica
- Replica under heavy read load (increase resources)
- Large transactions (monitor `pg_stat_activity`)

### Backup Failing

```bash
# Check backup logs
kubectl logs -n databases postgres-ha-1 | grep barman

# Test S3/MinIO connectivity
kubectl exec -n databases postgres-ha-1 -- \
  curl -I http://minio.storage:9000
```

**Common issues**:
- Invalid S3 credentials
- Bucket doesn't exist
- Network policy blocking access to MinIO/S3

### Connection Refused

```bash
# Check services exist
kubectl get svc -n databases

# Test connectivity from pod
kubectl run test-connection --rm -it \
  --image=postgres:16 \
  --restart=Never \
  -- psql -h postgres-ha-rw.databases.svc.cluster.local -U postgres -c "SELECT 1;"
```

**Common issues**:
- Service selector mismatch
- Pod not ready (check readiness probe)
- Network policy blocking traffic

## Security Considerations

### TLS Encryption

CloudNativePG generates self-signed certificates by default:

```yaml
spec:
  certificates:
    serverTLSSecret: postgres-server-cert
    replicationTLSSecret: postgres-replication-cert
    clientCASecret: postgres-ca
```

**All connections encrypted**:
- Client → PostgreSQL (TLS)
- Primary → Replica (TLS)
- Backups (encrypted at rest if S3 bucket configured)

### Authentication

Default authentication:
- **Superuser**: Generated automatically, stored in Secret
- **Application user**: Create via SQL or initdb scripts

```yaml
spec:
  bootstrap:
    initdb:
      database: app
      owner: app
      secret:
        name: app-user-credentials
```

### Network Policies

Restrict access to PostgreSQL:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-netpol
  namespace: databases
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: postgres-ha
  policyTypes:
    - Ingress
  ingress:
    # Allow from application namespace only
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 5432
```

### RBAC Considerations

Operator ServiceAccount permissions:
- **Read**: All Cluster/Backup CRDs
- **Write**: Pods, PVCs, Services, Secrets (in managed namespaces)
- **Cluster-scoped**: CRD definitions only

**Principle of least privilege**: Operator cannot access resources outside CNPG CRDs.

## Comparison: CloudNativePG vs Manual PostgreSQL

| Feature | Manual PostgreSQL | CloudNativePG |
|---------|------------------|---------------|
| **HA setup** | Hours of manual config | 10 minutes (declarative) |
| **Failover** | Manual intervention | Automatic (<30s) |
| **Backups** | Cron jobs, scripts | Built-in continuous archiving |
| **PITR** | Complex Barman setup | Single YAML manifest |
| **Upgrades** | Risky, downtime | Rolling, zero-downtime |
| **Monitoring** | Manual exporters | Native Prometheus metrics |
| **Connection pooling** | Separate PgBouncer setup | Optional sidecar |
| **Learning curve** | PostgreSQL expertise required | Kubernetes-native |

**CloudNativePG saves dozens of hours** while providing enterprise-grade capabilities.

## Comparison: CloudNativePG vs Alternatives

| Feature | CloudNativePG | Zalando Operator | Crunchy Operator |
|---------|---------------|------------------|------------------|
| **License** | Apache 2.0 (Open) | MIT (Open) | Apache 2.0 (Open + Enterprise) |
| **Maturity** | CNCF Sandbox | Production (2016) | Production (2018) |
| **Architecture** | Simple (operator + cluster) | Complex (sidecars) | Moderate |
| **Backups** | Built-in (Barman) | Separate (WAL-G) | Built-in (pgBackRest) |
| **PITR** | ✅ Native | ✅ Via WAL-G | ✅ Via pgBackRest |
| **Connection pooling** | ✅ PgBouncer sidecar | ✅ Separate pods | ✅ Separate pods |
| **Resource overhead** | Low | Moderate | Moderate-High |
| **Documentation** | Excellent | Good | Excellent |
| **Community** | Growing | Large | Large (commercial support) |

**Recommendation**: CloudNativePG for **simplicity + modern architecture**. Crunchy for **enterprise support**. Zalando for **battle-tested maturity**.

## Use Cases

### Development Databases

```yaml
# Lightweight single-instance cluster
spec:
  instances: 1  # No HA needed
  storage:
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
```

### Production HA Cluster

```yaml
# 3-replica HA with backups
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised  # Auto-failover during updates

  backup:
    barmanObjectStore:
      destinationPath: s3://prod-backups/
    retentionPolicy: "90d"

  monitoring:
    enablePodMonitor: true
```

### Read-Heavy Workload

```yaml
# 1 primary + 5 read replicas
spec:
  instances: 6

  # Application uses read-only service for reads
  # Distributes load across 5 replicas
```

## Uninstalling

### Remove Example Cluster

```bash
kubectl delete cluster postgres-ha -n databases
```

**IMPORTANT**: This deletes PVCs and all data. Ensure backups exist!

### Remove Operator

```bash
kubectl delete -k k8s/optional/medium-priority/cloudnative-pg/
```

## Learn More

- **Official Docs**: https://cloudnative-pg.io/documentation/
- **GitHub**: https://github.com/cloudnative-pg/cloudnative-pg
- **CNCF**: https://www.cncf.io/projects/cloudnative-pg/
- **Slack**: https://cloudnativepg.slack.com/
- **Best Practices**: https://cloudnative-pg.io/documentation/current/cloud_environments/

---

**Remember**: CloudNativePG is an **optional enhancement** for production-grade PostgreSQL. Your cluster is **already perfect** at 100/100 without it.
