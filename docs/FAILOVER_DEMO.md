# Fail-Over Demonstration Guide

This guide provides step-by-step procedures for demonstrating various fail-over scenarios in the infrastructure.

## Prerequisites

- Infrastructure deployed and running
- AWS CLI configured
- Access to AWS Console
- Basic familiarity with the application URL

## Test Scenarios

### 1. ECS Task Fail-Over (Container Level)

**Objective**: Demonstrate automatic container replacement when a task fails.

#### Method 1: Stop a Running Task

```bash
# List running tasks
aws ecs list-tasks \
  --cluster devops-showcase-dev-cluster \
  --service-name devops-showcase-dev-service \
  --region eu-central-1

# Stop a specific task (force immediate termination)
aws ecs stop-task \
  --cluster devops-showcase-dev-cluster \
  --task <task-id> \
  --region eu-central-1 \
  --reason "Fail-over demonstration"
```

**Expected Behavior**:
1. Task state changes to `STOPPING` → `STOPPED`
2. ECS service detects desired count not met
3. New task automatically launched within 30 seconds
4. New task starts, passes health checks
5. New task added to ALB target group
6. Service maintains availability throughout

**Timeline**: ~2-3 minutes for full recovery

#### Method 2: Kill Container from Inside

```bash
# Connect to ECS instance via SSM
aws ssm start-session --target <instance-id>

# Find container
docker ps

# Kill container
docker kill <container-id>
```

#### Monitoring the Fail-Over

**Terminal 1** - Watch ECS Service Events:
```bash
watch -n 2 'aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --query "services[0].events[0:5]" \
  --output table'
```

**Terminal 2** - Monitor Running Tasks:
```bash
watch -n 2 'aws ecs list-tasks \
  --cluster devops-showcase-dev-cluster \
  --service-name devops-showcase-dev-service \
  --query "taskArns" \
  --output table'
```

**Browser** - Refresh Application:
```bash
# Keep refreshing the application URL
while true; do
  curl -s http://<alb-dns-name>/ | grep "hostname"
  sleep 1
done
```

**What to Observe**:
- Task count temporarily drops from 2 to 1
- New task appears with different ID
- Hostname in application changes (showing different container)
- **Zero requests fail** - ALB routes around unhealthy task

---

### 2. ECS Service Auto-Scaling

**Objective**: Demonstrate automatic scaling based on load.

#### Generate Load

```bash
# Install Apache Bench (if not installed)
# macOS: brew install httpd
# Ubuntu: apt-get install apache2-utils

# Generate sustained load
ab -n 50000 -c 200 -t 300 http://<alb-dns-name>/
```

#### Alternative: Using Hey

```bash
# Install hey
go install github.com/rakyll/hey@latest

# Generate load
hey -z 5m -c 200 http://<alb-dns-name>/
```

#### Monitor Scaling Activity

**CloudWatch Metrics** (via Console):
1. Go to **CloudWatch** → **Container Insights** → **ECS Services**
2. Select your service
3. Watch CPU and Memory utilization graphs
4. Observe task count increasing

**CLI Monitoring**:
```bash
# Watch task count
watch -n 5 'aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --query "services[0].[desiredCount, runningCount]" \
  --output table'
```

**Expected Behavior**:
1. CPU utilization increases above 70%
2. CloudWatch alarm triggers (after 60s)
3. Auto-scaling policy increases desired count
4. New tasks start launching
5. Load distributed across more tasks
6. CPU utilization normalizes

**Timeline**: 
- Scale-out: 3-5 minutes
- Scale-in: 8-10 minutes (after load stops)

#### Verify Scaling Policy

```bash
# List scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/devops-showcase-dev-cluster/devops-showcase-dev-service
```

---

### 3. EC2 Instance Fail-Over

**Objective**: Demonstrate cluster capacity management when an instance fails.

#### Terminate an ECS Instance

```bash
# List ECS instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=devops-showcase-dev-ecs-instance" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]" \
  --output table

# Terminate one instance
aws ec2 terminate-instances --instance-ids <instance-id>
```

**Expected Behavior**:
1. Tasks running on terminated instance enter `STOPPING` state
2. Auto-scaling group detects unhealthy instance
3. New EC2 instance launches (within 3-5 minutes)
4. New instance joins ECS cluster
5. Tasks rescheduled on available capacity
6. Service maintains minimum desired count

**Timeline**: 5-8 minutes for full recovery

#### Detailed Monitoring

**Watch ASG Activity**:
```bash
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names devops-showcase-dev-ecs-asg-* \
  --query "AutoScalingGroups[0].[DesiredCapacity, Instances[*].InstanceId]" \
  --output table'
```

**Watch ECS Container Instances**:
```bash
watch -n 5 'aws ecs list-container-instances \
  --cluster devops-showcase-dev-cluster \
  --query "containerInstanceArns" \
  --output table'
```

---

### 4. RDS Multi-AZ Fail-Over

**Objective**: Demonstrate database fail-over with minimal application impact.

⚠️ **WARNING**: This test causes ~60-120 seconds of database connectivity interruption.

#### Initiate Fail-Over

```bash
# Reboot with fail-over flag
aws rds reboot-db-instance \
  --db-instance-identifier devops-showcase-dev-db \
  --force-failover \
  --region eu-central-1
```

**Alternative**: Use AWS Console
1. Navigate to **RDS** → **Databases**
2. Select `devops-showcase-dev-db`
3. Click **Actions** → **Reboot**
4. Check **"Reboot with fail-over?"**
5. Confirm

#### Monitor Fail-Over Process

**Terminal 1** - Watch RDS Status:
```bash
watch -n 5 'aws rds describe-db-instances \
  --db-instance-identifier devops-showcase-dev-db \
  --query "DBInstances[0].[DBInstanceStatus, AvailabilityZone, SecondaryAvailabilityZone]" \
  --output table'
```

**Terminal 2** - Test Application Connectivity:
```bash
# Continuously test database connectivity
while true; do
  timestamp=$(date '+%H:%M:%S')
  status=$(curl -s http://<alb-dns-name>/health | jq -r '.database')
  echo "$timestamp - Database: $status"
  sleep 1
done
```

**Terminal 3** - Monitor Application Logs:
```bash
aws logs tail /ecs/devops-showcase-dev-app --follow
```

**Expected Behavior**:

1. **T+0s**: Fail-over initiated
   - RDS status: `rebooting`
   
2. **T+30-60s**: Primary becomes unavailable
   - Application may show connection errors
   - Health checks may fail briefly
   
3. **T+60-90s**: Standby promoted to primary
   - DNS updated to new primary
   - New AZ becomes active
   
4. **T+90-120s**: Service restored
   - Application reconnects automatically
   - Health checks pass
   - Normal operation resumes

**What to Observe**:
- Brief period of connection errors (normal)
- Automatic retry and reconnection
- AZ change in RDS console
- Application continues after reconnection
- Request counter preserved (data persistence)

#### Verify Fail-Over Completion

```bash
# Check new primary AZ
aws rds describe-db-instances \
  --db-instance-identifier devops-showcase-dev-db \
  --query "DBInstances[0].[AvailabilityZone, SecondaryAvailabilityZone]" \
  --output table

# Check recent RDS events
aws rds describe-events \
  --source-identifier devops-showcase-dev-db \
  --source-type db-instance \
  --max-records 20
```

---

### 5. ALB Target Health Monitoring

**Objective**: Demonstrate ALB automatically routing around unhealthy targets.

#### Make Application Unhealthy

**Option 1**: Stop database (simulates backend failure)
```bash
# Stop RDS instance temporarily
aws rds stop-db-instance \
  --db-instance-identifier devops-showcase-dev-db
```

**Option 2**: Modify health check response (requires code change)

#### Monitor Target Health

**Via AWS Console**:
1. Go to **EC2** → **Target Groups**
2. Select ECS target group
3. Click **Targets** tab
4. Watch health status change

**Via CLI**:
```bash
watch -n 5 'aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --query "TargetHealthDescriptions[*].[Target.Id, TargetHealth.State, TargetHealth.Reason]" \
  --output table'
```

**Expected Behavior**:
1. Health check fails after 3 consecutive failures (90s)
2. Target marked as `unhealthy`
3. ALB stops sending new traffic to unhealthy target
4. Existing connections drained (30s deregistration delay)
5. All traffic routed to healthy targets

**Restore**:
```bash
# Start RDS instance
aws rds start-db-instance \
  --db-instance-identifier devops-showcase-dev-db
```

---

### 6. Network Partition Simulation

**Objective**: Demonstrate resilience to network issues.

#### Block Traffic with Security Group

```bash
# Get ECS security group ID
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=devops-showcase-dev-ecs-sg" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

# Remove ingress rule (blocks ALB → ECS)
aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3000 \
  --source-group <alb-security-group-id>
```

**Expected Behavior**:
- Health checks fail immediately
- ALB marks all targets unhealthy
- Returns 503 Service Unavailable

**Restore**:
```bash
# Add rule back
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3000 \
  --source-group <alb-security-group-id>
```

---

## Demonstration Script for Presentation

Use this script for a live demonstration:

### Script Overview (15 minutes)

**Setup (1 min)**:
```bash
# Open browser to application URL
# Open 2-3 terminal windows
# Show initial healthy state
```

**Demo 1 - Container Fail-Over (4 mins)**:
```bash
# Terminal 1: Show running tasks
aws ecs list-tasks --cluster devops-showcase-dev-cluster --service-name devops-showcase-dev-service

# Browser: Refresh page, note hostname
# Terminal 2: Stop one task
aws ecs stop-task --cluster <cluster> --task <task-id> --reason "Demo"

# Browser: Keep refreshing
# Show: Different hostnames rotating
# Show: No failed requests

# Terminal 1: Show new task launched
# Explain: ECS detected count < desired, launched replacement
```

**Demo 2 - Auto-Scaling (5 mins)**:
```bash
# Open CloudWatch in browser
# Show current CPU ~10-20%

# Generate load
ab -n 20000 -c 200 http://<alb-url>/

# Show CloudWatch: CPU rising
# Show ECS: Desired count increases
# Show ECS: New tasks launching
# Explain: Target tracking policy triggered at 70% CPU
```

**Demo 3 - Database Fail-Over (5 mins)**:
```bash
# AWS Console: RDS → Database
# Show Multi-AZ configuration
# Show current AZ

# Terminal: Monitor health endpoint
while true; do curl -s http://<alb>/health | jq '.database'; sleep 1; done

# AWS Console: Actions → Reboot with fail-over
# Terminal: Watch brief disconnection, then recovery
# AWS Console: Show AZ changed
# Browser: Application still works, data preserved
```

---

## Troubleshooting Fail-Over Issues

### Tasks Not Restarting

**Check**:
```bash
# Service events
aws ecs describe-services --cluster <cluster> --services <service>

# Look for: "unable to place task" errors
```

**Possible Causes**:
- Insufficient EC2 capacity
- Security group blocking container port
- Task definition errors

### Health Checks Always Failing

**Check**:
```bash
# View logs
aws logs tail /ecs/devops-showcase-dev-app --follow

# Check target group health
aws elbv2 describe-target-health --target-group-arn <arn>
```

**Possible Causes**:
- Application not listening on correct port
- `/health` endpoint returning non-200 status
- Security group blocking ALB → ECS traffic

### Database Fail-Over Takes Too Long

**Normal Duration**: 60-120 seconds

**If Longer**:
- Check RDS events for issues
- Verify Multi-AZ enabled
- Check for resource constraints

---

## Metrics to Collect During Demo

Present these metrics to demonstrate effectiveness:

| Metric | Before | During | After | Recovery Time |
|--------|--------|--------|-------|---------------|
| Available Tasks | 2 | 1 | 2 | ~2 min |
| Failed Requests | 0 | 0 | 0 | 0 |
| Response Time | ~50ms | ~50ms | ~50ms | N/A |
| Database Status | Connected | Disconnected | Connected | ~90s |

---

## Cleanup After Demonstration

```bash
# If you stopped RDS, start it
aws rds start-db-instance --db-instance-identifier devops-showcase-dev-db

# If you modified security groups, restore them
terraform apply

# Verify everything is healthy
aws ecs describe-services --cluster <cluster> --services <service>
```

---

**Next Steps**: After demonstrating fail-over, discuss:
- How these patterns apply to production
- Additional monitoring and alerting
- Disaster recovery procedures
- Cost implications of HA architecture

