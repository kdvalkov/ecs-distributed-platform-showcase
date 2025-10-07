# Deployment Guide (Local Setup - Legacy)

> **⚠️ DEPRECATION NOTICE**
> 
> This guide covers **local deployment** which requires installing Terraform, Docker, and AWS CLI on your machine.
> 
> **We now recommend using GitHub Actions** which requires NO local tools:
> - ✅ **Quick Start:** [GITHUB_ACTIONS_QUICKSTART.md](GITHUB_ACTIONS_QUICKSTART.md) - 5 minutes
> - ✅ **Complete Guide:** [GITHUB_ACTIONS_AUTOMATION.md](GITHUB_ACTIONS_AUTOMATION.md) - Full documentation
> 
> The guide below remains available for advanced users who need local development capabilities.

---

## Local Deployment (Advanced)

Detailed step-by-step instructions for deploying the DevOps Showcase infrastructure **locally**.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with administrative access
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.12.0 installed
- [ ] Docker installed (for local testing)
- [ ] Git installed
- [ ] GitHub account (for CI/CD)
- [ ] Sufficient AWS service limits (check below)

### AWS Service Limits to Verify

```bash
# Check VPC limit
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE

# Check ECS cluster limit
aws service-quotas get-service-quota \
  --service-code ecs \
  --quota-code L-21C621EB
```

Minimum required:
- VPCs: 1 available
- Elastic IPs: 2 available
- EC2 instances: 4 available (t3.small or equivalent)
- RDS instances: 1 available (db.t3.micro)

## Deployment Steps

### Phase 1: AWS Account Setup

#### 1.1 Create IAM User for Terraform (Recommended)

```bash
# Create user
aws iam create-user --user-name terraform-devops-showcase

# Attach required policies
aws iam attach-user-policy \
  --user-name terraform-devops-showcase \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-user-policy \
  --user-name terraform-devops-showcase \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# Create access key
aws iam create-access-key --user-name terraform-devops-showcase
```

**Save the Access Key ID and Secret Access Key!**

#### 1.2 Configure AWS CLI Profile

```bash
aws configure --profile devops-showcase
# Enter Access Key ID
# Enter Secret Access Key
# Region: eu-central-1
# Output format: json

# Test configuration
aws sts get-caller-identity --profile devops-showcase
```

### Phase 2: Repository Setup

#### 2.1 Clone or Initialize Repository

```bash
# If starting fresh
git init devops_showcase
cd devops_showcase

# Copy all files from the project structure
```

#### 2.2 Create .gitignore

```bash
cat > .gitignore << 'EOF'
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
.terraform.lock.hcl
terraform.tfvars
*.tfvars
!terraform.tfvars.example

# Environment files
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Dependencies
node_modules/
EOF
```

#### 2.3 Initialize Git Repository

```bash
git add .
git commit -m "Initial commit: DevOps showcase infrastructure"

# Create GitHub repository and push
gh repo create devops_showcase --public --source=. --remote=origin
git push -u origin main
```

### Phase 3: Terraform Deployment

#### 3.1 Prepare Terraform Variables

```bash
cd terraform

# Create terraform.tfvars from template
cat > terraform.tfvars << 'EOF'
aws_region   = "us-east-1"
environment  = "dev"
project_name = "devops-showcase"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# ECS Configuration
ecs_instance_type  = "t3.small"
ecs_cluster_size   = 2
ecs_desired_count  = 2
ecs_min_capacity   = 2
ecs_max_capacity   = 4

# Database Configuration
db_instance_class = "db.t3.micro"
db_multi_az       = true
db_username       = "dbadmin"
db_password       = "CHANGE_THIS_PASSWORD_123!"  # ⚠️ Use a strong password!

# Auto-scaling thresholds
cpu_target_value    = 70
memory_target_value = 80
EOF

# ⚠️ IMPORTANT: Change the db_password to something secure!
```

#### 3.2 Initialize Terraform

```bash
# Initialize providers and modules
terraform init

# Validate configuration
terraform validate

# Check formatting
terraform fmt -recursive
```

**Expected Output**:
```
Initializing modules...
Downloading terraform-aws-modules/vpc/aws 5.x.x
Downloading terraform-aws-modules/alb/aws 9.x.x
...
Terraform has been successfully initialized!
```

#### 3.3 Review Execution Plan

```bash
# Generate and review plan
terraform plan -out=tfplan

# Review the plan carefully!
# Expected resources: ~60-70 resources to create
```

**Key Resources to Verify in Plan**:
- ✅ VPC with 6 subnets (2 public, 2 private, 2 database)
- ✅ 1 fck-nat Instance (t4g.micro spot for cost savings)
- ✅ Application Load Balancer
- ✅ ECS Cluster with capacity provider
- ✅ Auto Scaling Group (2 instances)
- ✅ RDS PostgreSQL (Multi-AZ)
- ✅ ECR Repository
- ✅ Security Groups (ALB, ECS, RDS, fck-nat)
- ✅ IAM Roles (task execution, task, instance, fck-nat)
- ✅ CloudWatch Log Group

#### 3.4 Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# This will take approximately 15-20 minutes
# Grab a coffee! ☕
```

**Progress Indicators**:
- 0-5 min: Network resources (VPC, subnets, IGW, fck-nat)
- 5-10 min: RDS instance creation (slowest component)
- 10-15 min: ECS cluster, EC2 instances launching
- 15-20 min: Load balancer, target groups, final configurations

#### 3.5 Save Outputs

```bash
# Display all outputs
terraform output

# Save important outputs
echo "ECR Repository: $(terraform output -raw ecr_repository_url)" > ../deployment-info.txt
echo "Application URL: $(terraform output -raw application_url)" >> ../deployment-info.txt
echo "RDS Endpoint: $(terraform output -raw rds_endpoint)" >> ../deployment-info.txt

# View formatted summary
terraform output deployment_summary
```

### Phase 4: Application Deployment

#### 4.1 Build Docker Image Locally

```bash
cd ../app

# Test build locally
docker build -t devops-showcase-app:test .

# Test run locally (optional)
docker run -d -p 3000:3000 \
  -e DB_HOST=localhost \
  -e DB_PORT=5432 \
  -e DB_NAME=postgres \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  --name devops-test \
  devops-showcase-app:test

# Test health endpoint
curl http://localhost:3000/health

# Clean up test container
docker stop devops-test && docker rm devops-test
```

#### 4.2 Push Image to ECR

```bash
# Get ECR repository URL
cd ../terraform
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -raw aws_region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and tag image
cd ../app
docker build -t devops-showcase-app .
docker tag devops-showcase-app:latest $ECR_REPO:latest

# Push to ECR
docker push $ECR_REPO:latest
```

**Expected Output**:
```
The push refers to repository [xxxxx.dkr.ecr.eu-central-1.amazonaws.com/devops-showcase-dev-app]
latest: digest: sha256:xxxxx size: 1234
```

#### 4.3 Deploy to ECS

```bash
# Update ECS service to pull new image
aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --region eu-central-1

# Monitor deployment
aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --query 'services[0].events[0:5]' \
  --output table
```

#### 4.4 Wait for Deployment

```bash
# Watch task status (repeat until running)
watch -n 10 'aws ecs list-tasks \
  --cluster devops-showcase-dev-cluster \
  --service-name devops-showcase-dev-service \
  --desired-status RUNNING \
  --region us-east-1'
```

**Deployment typically takes 3-5 minutes**:
1. Pull image from ECR (~1 min)
2. Start container (~30s)
3. Health checks pass (~1-2 min)
4. Register with ALB (~30s)

### Phase 5: Verification

#### 5.1 Check Application Health

```bash
# Get ALB DNS name
cd ../terraform
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health endpoint
curl http://$ALB_DNS/health

# Expected output:
# {"status":"healthy","database":"connected"}

# Test main application
curl http://$ALB_DNS/

# Should return HTML
```

#### 5.2 Verify in Browser

Open in web browser:
```
http://<alb-dns-name>
```

**Expected**:
- Beautiful dashboard showing container info
- Database status: "Connected"
- Request counter incrementing with each refresh
- Different hostnames when refreshing (load balancing)

#### 5.3 Check CloudWatch Logs

```bash
# View recent logs
aws logs tail /ecs/devops-showcase-dev-app --follow

# Look for:
# "✅ Database initialized successfully"
# "🚀 DevOps Showcase Application Started"
```

#### 5.4 Verify Auto-Scaling Setup

```bash
# Check scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/devops-showcase-dev-cluster/devops-showcase-dev-service

# Should show CPU and memory target tracking policies
```

### Phase 6: CI/CD Setup (Optional)

#### 6.1 Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these secrets:

   **AWS_ACCESS_KEY_ID**:
   ```
   Your AWS access key ID
   ```

   **AWS_SECRET_ACCESS_KEY**:
   ```
   Your AWS secret access key
   ```

#### 6.2 Test GitHub Actions Workflow

```bash
# Make a small change to trigger workflow
cd app
echo "# Build $(date)" >> README.md
git add README.md
git commit -m "Test: Trigger CI/CD pipeline"
git push origin main

# Watch workflow in GitHub Actions tab
```

#### 6.3 Enable Automatic ECS Updates (Optional)

Edit `.github/workflows/deploy.yml` and uncomment:

```yaml
- name: Update ECS service
  run: |
    aws ecs update-service \
      --cluster devops-showcase-dev-cluster \
      --service devops-showcase-dev-service \
      --force-new-deployment \
      --region ${{ env.AWS_REGION }}
```

## Post-Deployment Configuration

### Enable Enhanced Monitoring

```bash
# Enable Container Insights (already done in Terraform)
# Verify it's active:
aws ecs describe-clusters \
  --clusters devops-showcase-dev-cluster \
  --include SETTINGS
```

### Set Up CloudWatch Alarms (Recommended)

```bash
# Create CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name devops-showcase-high-cpu \
  --alarm-description "Alert when CPU exceeds 90%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=devops-showcase-dev-cluster \
               Name=ServiceName,Value=devops-showcase-dev-service
```

### Configure Database Backups

```bash
# Verify backup settings
aws rds describe-db-instances \
  --db-instance-identifier devops-showcase-dev-db \
  --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow]'

# Should show: 7 days retention, window: 03:00-06:00 UTC
```

## Troubleshooting Deployment

### Issue: Terraform Apply Fails

**Error**: "Error creating VPC: VpcLimitExceeded"

**Solution**:
```bash
# Check VPC limit
aws ec2 describe-account-attributes --attribute-names vpc-max-security-groups-per-interface

# Request limit increase via AWS Console
```

### Issue: ECS Tasks Not Starting

**Check Service Events**:
```bash
aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --query 'services[0].events[0:10]'
```

**Common Causes**:
1. Image not in ECR → Push image again
2. Insufficient EC2 capacity → Check ASG launched instances
3. Security group issues → Verify security group rules

### Issue: Health Checks Failing

**Check Target Health**:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

**Test Container Directly**:
```bash
# Get container instance IP
aws ecs describe-tasks \
  --cluster devops-showcase-dev-cluster \
  --tasks $(aws ecs list-tasks --cluster devops-showcase-dev-cluster --query 'taskArns[0]' --output text) \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
  --output text

# SSH to ECS instance and curl container
curl http://<container-ip>:3000/health
```

### Issue: Database Connection Fails

**Check RDS Status**:
```bash
aws rds describe-db-instances \
  --db-instance-identifier devops-showcase-dev-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]'
```

**Verify Security Group**:
```bash
# ECS SG should allow outbound to RDS
# RDS SG should allow inbound from ECS SG on port 5432
```

## Deployment Checklist

Use this checklist to ensure complete deployment:

- [ ] AWS account configured and tested
- [ ] Terraform initialized and validated
- [ ] Infrastructure deployed (terraform apply)
- [ ] All outputs saved
- [ ] Docker image built and tested locally
- [ ] Image pushed to ECR successfully
- [ ] ECS service deployed and running
- [ ] Application accessible via ALB DNS
- [ ] Database connection working
- [ ] Request counter incrementing
- [ ] Load balancing working (different hostnames)
- [ ] GitHub Actions configured (if using CI/CD)
- [ ] CloudWatch logs showing activity
- [ ] Auto-scaling policies configured
- [ ] All components healthy in AWS Console

## Next Steps

After successful deployment:

1. **Test Fail-Over**: See [FAILOVER_DEMO.md](./FAILOVER_DEMO.md)
2. **Configure Monitoring**: Set up CloudWatch dashboards
3. **Add Custom Domain**: Configure Route 53 + ACM certificate
4. **Enable HTTPS**: Add SSL certificate to ALB
5. **Set Up Alarms**: Configure alerting for critical metrics
6. **Document Runbooks**: Create operational procedures

## Estimated Deployment Time

| Phase | Duration | Notes |
|-------|----------|-------|
| Prerequisites | 30 min | First time only |
| Repository Setup | 10 min | One time |
| Terraform Deployment | 20 min | AWS resource creation |
| Application Deployment | 10 min | Build and push image |
| Verification | 10 min | Testing and validation |
| **Total** | **~80 min** | **First deployment** |
| **Subsequent** | **~15 min** | **Updates only** |

## Cost Tracking

Monitor costs during deployment:

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://cost-filter.json

# cost-filter.json:
{
  "Tags": {
    "Key": "Project",
    "Values": ["DevOps-Showcase"]
  }
}
```

---

**Deployment Complete!** 🎉

Your infrastructure is now running and ready for demonstration. Proceed to fail-over testing or begin your presentation!
