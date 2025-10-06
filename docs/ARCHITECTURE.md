# Architecture Deep Dive

## Overview

This document provides a detailed technical explanation of the infrastructure architecture, component interactions, and design decisions.

## Network Architecture

### VPC Design

```
VPC (10.0.0.0/16)
├── Availability Zone A (eu-central-1a)
│   ├── Public Subnet (10.0.2.0/20)      → ALB, NAT Gateway
│   ├── Private Subnet (10.0.18.0/20)    → ECS Tasks
│   └── Database Subnet (10.0.34.0/20)   → RDS Primary
│
├── AZ-2 (eu-central-1b)
    ├── Public Subnet (10.0.3.0/20)      → ALB
    ├── Private Subnet (10.0.1.0/20)     → ECS Tasks
    └── Database Subnet (10.0.5.0/20)    → RDS Standby
```

### Subnet Strategy

- **Public Subnets**: Internet-facing resources (ALB, NAT Gateway)
- **Private Subnets**: Application layer (ECS tasks on EC2)
- **Database Subnets**: Data layer (RDS instances, isolated)

### Network Flow

1. **Inbound Traffic (HTTPS)**:
   ```
   User Browser → DNS Query (showcase.valkov.cloud)
   → Route53 → A Record (Alias to ALB)
   → Internet Gateway → ALB:443 (Public Subnet, SSL termination)
   → ALB:80 (redirects to 443)
   → ECS Tasks:3000 (Private Subnet, HTTP)
   → RDS:5432 (Database Subnet)
   ```

2. **Outbound Traffic**:
   ```
   ECS Tasks → NAT Gateway (Public Subnet) → Internet Gateway → Internet
   ```

## DNS and SSL/TLS Architecture

### Route53 Configuration

**Hosted Zone**: `valkov.cloud` (created manually)
- **Nameservers**: Configured in Namecheap (domain registrar)
- **DNS Records**: Managed by Terraform

#### DNS Records Created by Terraform

1. **A Record (Alias)**:
   ```
   Name: showcase.valkov.cloud
   Type: A (Alias)
   Target: ALB DNS name (auto-resolves to ALB IPs)
   Evaluate Target Health: true
   ```

2. **Certificate Validation Records**:
   ```
   Name: _<random>.showcase.valkov.cloud
   Type: CNAME
   Value: _<random>.acm-validations.aws.
   Purpose: Automatic ACM certificate validation
   ```

### ACM Certificate

**Domain**: `showcase.valkov.cloud`
**Validation Method**: DNS (automatic)

#### Certificate Issuance Flow

```
1. Terraform creates ACM certificate request
   ↓
2. ACM generates DNS validation records
   ↓
3. Terraform creates Route53 CNAME records
   ↓
4. ACM verifies DNS records (takes 5-10 minutes)
   ↓
5. Certificate issued and attached to ALB
   ↓
6. Automatic renewal (before expiry)
```

#### Why DNS Validation?

- ✅ **Automated**: No manual email approval
- ✅ **Continuous**: Works for auto-renewal
- ✅ **Secure**: Proves domain control via DNS
- ✅ **Fast**: Validation completes in 5-10 minutes

### HTTPS/TLS Configuration

#### ALB Listener Configuration

**HTTP Listener (Port 80)**:
```hcl
listener {
  port     = 80
  protocol = "HTTP"
  
  # Redirect all HTTP to HTTPS
  redirect {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"  # Permanent redirect
  }
}
```

**HTTPS Listener (Port 443)**:
```hcl
listener {
  port            = 443
  protocol        = "HTTPS"
  certificate_arn = aws_acm_certificate.showcase.arn
  
  # Forward to ECS target group
  forward {
    target_group = ecs_app
  }
}
```

#### SSL/TLS Benefits

1. **Encryption**: Data encrypted in transit (browser ↔ ALB)
2. **Authentication**: Verifies server identity
3. **Trust**: Browser shows padlock icon
4. **SEO**: Google ranks HTTPS sites higher
5. **Free**: ACM certificates are free with auto-renewal

#### SSL Termination at ALB

```
Browser ←─ HTTPS (encrypted) ─→ ALB ←─ HTTP (unencrypted) ─→ ECS Tasks
```

**Why terminate SSL at ALB?**
- ✅ Offloads encryption from application
- ✅ Centralizes certificate management
- ✅ Private subnet traffic doesn't need encryption
- ✅ Simplifies container configuration

### Domain Configuration Steps

**One-time manual setup**:

1. Create Route53 hosted zone in AWS Console:
   ```
   Domain: valkov.cloud
   Type: Public hosted zone
   ```

2. Copy nameservers from Route53:
   ```
   ns-123.awsdns-12.com
   ns-456.awsdns-45.net
   ns-789.awsdns-78.org
   ns-012.awsdns-01.co.uk
   ```

3. Update Namecheap DNS settings:
   ```
   Domain → Manage → Custom DNS
   Add all 4 nameservers
   ```

4. Wait for DNS propagation (5-60 minutes)

5. Run Terraform - certificate validates automatically

## Compute Architecture

### ECS on EC2 Configuration

#### Cluster Design

- **Capacity Provider**: Custom EC2-based capacity provider
- **Launch Type**: EC2 (for better control and cost optimization)
- **Instance Type**: t3.small (2 vCPU, 2 GiB RAM)
- **AMI**: ECS-optimized Amazon Linux 2

#### Why EC2 over Fargate?

✅ **Chosen: ECS on EC2**
- Lower cost for sustained workloads
- More control over instance types
- Better for learning infrastructure management
- Demonstrates auto-scaling groups

❌ **Alternative: Fargate**
- Serverless, no instance management
- Higher cost per vCPU/GB
- Less visibility into underlying infrastructure

### Task Definition

```json
{
  "family": "devops-showcase-dev-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["EC2"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [{
    "name": "app",
    "image": "<ecr-repo>:latest",
    "portMappings": [{
      "containerPort": 3000,
      "protocol": "tcp"
    }],
    "healthCheck": {
      "command": ["CMD-SHELL", "node -e \"...\""],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    }
  }]
}
```

### Service Configuration

- **Desired Count**: 2 tasks (minimum for high availability)
- **Network Mode**: `awsvpc` (each task gets its own ENI)
- **Load Balancing**: Integrated with ALB target group
- **Health Checks**: Container + ALB health checks

## Load Balancing

### Application Load Balancer

#### Architecture

```
                        ALB
                         │
            ┌────────────┴────────────┐
            │                         │
      Listener:443              Listener:80
      (HTTPS + Cert)            (→ Redirect 443)
            │                         │
            └────────┬────────────────┘
                     │
               Target Group
                     │
                Health Check
                GET /health
                Every 30s
                     │
       ┌─────────────┴─────────────┐
       │                           │
  ECS Task 1                  ECS Task 2
(10.0.0.x:3000)            (10.0.1.x:3000)
```

#### Target Group Configuration

- **Protocol**: HTTP
- **Port**: 3000
- **Target Type**: IP (required for awsvpc network mode)
- **Health Check Path**: `/health`
- **Health Check Interval**: 30 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 3 consecutive failures
- **Deregistration Delay**: 30 seconds

#### Health Check Logic

The application provides two health check endpoints:

1. **/health** - Deep health check
   - Verifies database connectivity
   - Returns 200 if healthy, 503 if unhealthy
   - Used by ALB for routing decisions

2. **/ready** - Readiness check
   - Simple response confirming app is running
   - Used for quick liveness checks

## Database Architecture

### RDS PostgreSQL Multi-AZ

```
┌─────────────────────────────────────────┐
│          RDS Multi-AZ Setup             │
├─────────────────────────────────────────┤
│  Primary Instance (AZ-A)                │
│  ├── Active: Read/Write                 │
│  ├── Synchronous Replication ─────────┐ │
│  └── Automatic Backups                 │ │
│                                         │ │
│  Standby Instance (AZ-B)               ◄─┘
│  ├── Passive: No Read Access           │
│  ├── Automatic Fail-Over               │
│  └── Promoted on Primary Failure       │
└─────────────────────────────────────────┘
```

### Fail-Over Mechanism

**Automatic Fail-Over Triggers**:
1. Primary instance failure
2. AZ outage
3. Database instance reboot with fail-over
4. DB instance modification (some operations)

**Fail-Over Process** (typically 60-120 seconds):
1. AWS detects primary instance failure
2. DNS record updated to point to standby
3. Standby promoted to primary
4. Application reconnects automatically

### Connection String

Application uses the RDS endpoint (DNS name):
```
devops-showcase-dev-db.xxxxx.eu-central-1.rds.amazonaws.com:5432
```

This endpoint automatically points to the current primary instance.

## Auto-Scaling

### ECS Service Auto-Scaling

#### Target Tracking Policies

1. **CPU-based Scaling**:
   ```
   Target: 70% CPU utilization
   Scale Out: Add task if avg > 70% for 60s
   Scale In: Remove task if avg < 70% for 300s
   ```

2. **Memory-based Scaling**:
   ```
   Target: 80% Memory utilization
   Scale Out: Add task if avg > 80% for 60s
   Scale In: Remove task if avg < 80% for 300s
   ```

#### Capacity Limits

- **Minimum**: 2 tasks (high availability)
- **Maximum**: 4 tasks (cost control)
- **Desired**: 2 tasks (normal operation)

### EC2 Auto-Scaling Group

#### Cluster Capacity Provider

```
Managed Scaling:
- Target Capacity: 80%
- Minimum Step: 1 instance
- Maximum Step: 2 instances
```

When ECS needs more capacity:
1. Tasks pending placement due to insufficient resources
2. Capacity provider triggers ASG scale-out
3. New EC2 instance launched
4. Instance joins ECS cluster
5. Tasks placed on new instance

## Security Architecture

### Security Groups

```
┌─────────────────────────────────────────────┐
│  ALB Security Group                         │
│  Ingress: 0.0.0.0/0:80 (HTTP)              │
│           0.0.0.0/0:443 (HTTPS)            │
│  Egress: ECS SG on :3000                    │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  ECS Security Group                         │
│  Ingress: ALB SG on :3000                   │
│  Egress: RDS SG on :5432, Internet          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  RDS Security Group                         │
│  Ingress: ECS SG on :5432                   │
│  Egress: None                               │
└─────────────────────────────────────────────┘
```

### IAM Roles

#### 1. ECS Task Execution Role
- **Purpose**: Pull images, write logs
- **Permissions**:
  - `ecr:GetAuthorizationToken`
  - `ecr:BatchCheckLayerAvailability`
  - `ecr:GetDownloadUrlForLayer`
  - `ecr:BatchGetImage`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`

#### 2. ECS Task Role
- **Purpose**: Application runtime permissions
- **Permissions**:
  - `logs:PutLogEvents` (application logging)
  - Custom permissions as needed

#### 3. ECS Instance Role
- **Purpose**: EC2 instances to join cluster
- **Permissions**:
  - `ecs:RegisterContainerInstance`
  - `ecs:DeregisterContainerInstance`
  - `ecs:Submit*`
  - `ecr:GetAuthorizationToken`

## Monitoring & Observability

### CloudWatch Integration

#### Container Insights

Enabled on ECS cluster for enhanced monitoring:
- CPU and memory utilization (cluster, service, task)
- Network metrics (bytes in/out, packets)
- Storage metrics (read/write operations)

#### Custom Metrics

Application can publish custom metrics:
```javascript
const cloudwatch = new AWS.CloudWatch();
await cloudwatch.putMetricData({
  Namespace: 'DevOpsShowcase',
  MetricData: [{
    MetricName: 'RequestCount',
    Value: count,
    Unit: 'Count'
  }]
}).promise();
```

#### Log Groups

- `/ecs/devops-showcase-dev-app` - Application logs
- `/aws/rds/instance/devops-showcase-dev-db/postgresql` - Database logs

### Alarms (Not Implemented - Future Enhancement)

Recommended alarms:
1. ECS CPU > 90% for 5 minutes
2. ECS Memory > 95% for 5 minutes
3. ALB 5XX errors > 10 in 5 minutes
4. RDS connections > 80% of max
5. RDS CPU > 80% for 10 minutes

## Deployment Strategy

### Rolling Updates

ECS service configuration:
```
Minimum Healthy Percent: 100%
Maximum Percent: 200%
```

**Deployment Process**:
1. Start new task with updated image
2. Wait for health checks to pass
3. Add new task to ALB target group
4. Drain connections from old task (30s)
5. Stop old task
6. Repeat for remaining tasks

**Result**: Zero-downtime deployments

### CI/CD Pipeline

```
GitHub Push (main branch)
    │
    ▼
GitHub Actions Workflow
    │
    ├─── Build Docker Image
    ├─── Tag with SHA and 'latest'
    ├─── Push to ECR
    │
    ▼
Manual or Automatic ECS Update
    │
    ▼
Rolling Update (as described above)
```

## Cost Optimization Strategies

### Current Configuration Costs

| Component | Cost/Month (Estimate) |
|-----------|----------------------|
| 2× t3.small EC2 | ~$30 |
| ALB | ~$20 |
| RDS db.t3.micro Multi-AZ | ~$30 |
| 1× NAT Gateway | ~$32 |
| Route53 Hosted Zone | ~$0.50 |
| Route53 Queries (1M) | ~$0.40 |
| ACM Certificate | **FREE** |
| Data Transfer (10GB) | ~$1 |
| **Total** | **~$114** |

### Optimization Options

1. **Development Environment**:
   - ✅ Already using Single NAT Gateway (configured)
   - RDS Single-AZ: Save $15/month
   - Smaller instances: Variable savings

2. **Reserved Instances** (1-year commitment):
   - EC2 RI: Save ~30-40%
   - RDS RI: Save ~35-50%

3. **Spot Instances for ECS**:
   - Save ~70% on EC2 costs
   - Trade-off: Possible interruptions

## Design Decisions & Trade-offs

### ✅ Choices Made

| Decision | Rationale |
|----------|-----------|
| ECS on EC2 | Lower cost, better for learning |
| Multi-AZ RDS | Demonstrate fail-over capabilities |
| Application Load Balancer | Layer 7 routing, better health checks |
| PostgreSQL | Open-source, good performance |
| Terraform Community Modules | Best practices, faster development |

### 🔄 Alternative Approaches

| Alternative | Pros | Cons |
|------------|------|------|
| ECS Fargate | Serverless, no instance management | Higher cost |
| EKS (Kubernetes) | More features, portable | Complex, expensive |
| Beanstalk | Fully managed | Less control |
| Lambda + API Gateway | Serverless, pay-per-use | Stateless, cold starts |

## Scalability Considerations

### Horizontal Scaling

- **ECS Tasks**: Scale from 2 to 4 (configured)
- **EC2 Instances**: Scale from 2 to 4 (configured)
- **Can be increased** by adjusting variables

### Vertical Scaling

- **Task Resources**: Increase CPU/memory in task definition
- **Instance Size**: Change `ecs_instance_type` variable
- **RDS Instance**: Change `db_instance_class` variable

### Database Scaling

- **Read Replicas**: Add for read-heavy workloads
- **Connection Pooling**: Implemented in application (pg pool)
- **RDS Proxy**: Consider for many connections

## High Availability Features

| Component | HA Strategy |
|-----------|------------|
| DNS | Route53 with 4 geographically distributed nameservers |
| SSL/TLS | ACM certificate with automatic renewal |
| Application | 2+ tasks across multiple AZs |
| Load Balancer | Multi-AZ by default |
| Database | Multi-AZ with automatic fail-over |
| Network | 1 NAT Gateway (single AZ for cost savings) |

**Result**: No single point of failure

## Security Features

| Feature | Implementation |
|---------|----------------|
| Encryption in Transit | HTTPS with TLS 1.2+ (ALB to browser) |
| Certificate Management | AWS Certificate Manager (ACM) with auto-renewal |
| HTTP Security | Automatic HTTP→HTTPS redirect (301 permanent) |
| DNS Security | DNSSEC available (optional, can be enabled) |
| Domain Validation | DNS-based ACM validation (no email required) |
| Private Communication | ALB→ECS over private subnets (HTTP acceptable) |

---

This architecture demonstrates production-ready patterns suitable for real-world applications while remaining cost-effective for demonstration purposes.
