# DevOps Infrastructure Showcase

A comprehensive demonstration of AWS infrastructure automation using Terraform, showcasing best practices for deploying containerized applications with high availability, auto-scaling, and fail-over capabilities.

## 🏗️ Architecture Overview

This project implements a production-ready infrastructure on AWS with:

- **Application Load Balancer (ALB)** - Distributes traffic across multiple containers with HTTPS
- **ECS on EC2** - Container orchestration with auto-scaling
- **RDS PostgreSQL (Multi-AZ)** - Highly available database with automatic fail-over
- **Route53 & ACM** - DNS management and SSL/TLS certificates
- **ECR** - Private Docker registry for container images
- **VPC** - Multi-AZ network architecture with public and private subnets
- **fck-nat** - Cost-effective NAT solution (saves ~$29/month vs AWS NAT Gateway)
- **CloudWatch** - Logging and monitoring with Container Insights

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Application Load    │
              │     Balancer         │
              │   (Public Subnets)   │
              └──────────┬───────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│   ECS Service   │           │   ECS Service   │
│   (Container)   │           │   (Container)   │
│  Private Subnet │           │  Private Subnet │
│      AZ-1       │           │      AZ-2       │
└────────┬────────┘           └────────┬────────┘
         │                               │
         └───────────────┬───────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │    RDS PostgreSQL    │
              │      (Multi-AZ)      │
              │  Database Subnets    │
              └──────────────────────┘
```

## 🚀 Features

### Infrastructure
- ✅ **Multi-AZ deployment** for high availability
- ✅ **Auto-scaling** based on CPU and memory utilization
- ✅ **Health checks** with automatic instance replacement
- ✅ **Zero-downtime deployments** with rolling updates
- ✅ **Cost-optimized NAT** using [fck-nat](https://github.com/AndrewGuenther/fck-nat) (~90% cheaper than NAT Gateway)
- ✅ **Infrastructure as Code** using Terraform with community modules
- ✅ **CI/CD pipeline** with GitHub Actions

### Application
- 🎨 **Beautiful web dashboard** showing real-time infrastructure info
- 📊 **Request counter** stored in PostgreSQL database
- 🏥 **Health check endpoints** for load balancer
- 🐳 **Container metadata** display (hostname, resources, uptime)
- 🌍 **AWS metadata** (region, AZ, ECS task info)

## 📋 Prerequisites

**Minimal Requirements:**
- **GitHub Account** - To run workflows
- **AWS Account** - With appropriate permissions
- **10 minutes** - For initial setup

**That's it!** No local tools needed (Terraform, Docker, AWS CLI). Everything runs in GitHub Actions.

## 🚀 Quick Start (GitHub Actions - Recommended)

**Complete deployment without installing anything locally!**

See **[docs/GITHUB_ACTIONS_QUICKSTART.md](docs/GITHUB_ACTIONS_QUICKSTART.md)** for the fastest way to deploy (5 minutes).

### Summary:

1. **Configure GitHub Secrets** (2 min)
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Bootstrap S3 Backend** (1 min)
   ```
   Actions → "Bootstrap S3 Backend" → Run workflow
   ```

3. **Update Repository Name** (1 min)
   - Edit `terraform/environments/dev.tfvars`
   - Set your `github_repo_name`

4. **Deploy Infrastructure** (20 min)
   ```
   Actions → "Deploy Infrastructure" → Run workflow
   ```

5. **Configure DNS** (5 min)
   - Create Route53 hosted zone for valkov.cloud manually
   - Copy nameservers and add to Namecheap
   - Wait for DNS propagation

6. **Access Application** (0 min)
   - Visit https://showcase.valkov.cloud
   - (Or use ALB DNS directly: http://<alb-dns>)

**Total Time: ~29 minutes** 🎉

---

## 🔧 Alternative: Local Development Setup

If you need to run Terraform locally (for development or testing), you can still do so:

### Prerequisites for Local Setup
- **Terraform** >= 1.12.2
- **AWS CLI** configured with credentials
- **Docker** (optional, for local testing)

### Local Deployment Steps

1. Clone the repository
2. Update `github_repo_name` in `terraform/environments/dev.tfvars`
3. Create Route53 hosted zone manually:
   - Go to AWS Console → Route53 → Create hosted zone
   - Domain name: valkov.cloud
   - Copy the nameservers and configure them in Namecheap
4. Run Terraform:
   ```bash
   cd terraform
   terraform init
   terraform plan -var-file="environments/dev.tfvars"
   terraform apply -var-file="environments/dev.tfvars"
   ```
5. The infrastructure will be created (DB password auto-generated, SSL certificate issued)
6. Access application via https://showcase.valkov.cloud (or ALB DNS)

**Note:** For most users, the GitHub Actions method above is simpler and requires no local tools.

## 🤖 GitHub Actions Automation (Zero Local Commands!)

This project includes **complete GitHub Actions automation** - you don't need to run ANY commands locally!

### Available Workflows

#### 1. **Bootstrap S3 Backend** (`.github/workflows/bootstrap.yml`)
Creates S3 bucket for Terraform state storage with proper security:
- Enables versioning and encryption
- Blocks public access
- Configures lifecycle policies
- **Trigger:** Manual (workflow_dispatch)

#### 2. **Deploy Infrastructure** (`.github/workflows/terraform-deploy.yml`)
Deploy and update infrastructure:
- **Plan** - Preview changes (safe, no modifications)
- **Apply** - Deploy infrastructure (~20 minutes)
- **Trigger:** Manual with user input validation
- **Authentication:** AWS Access Keys (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

#### 3. **Destroy Infrastructure** (`.github/workflows/terraform-destroy.yml`)
Safely destroy all resources:
- **Destroy** - Delete all resources (requires "DESTROY" confirmation)
- **Trigger:** Manual only with multiple confirmations
- **Authentication:** AWS Access Keys (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

#### 4. **Deploy Application to ECR** (`.github/workflows/deploy.yml`)
Builds and pushes Docker image automatically:
- Uses GitHub OIDC for secure authentication
- **Trigger:** Push to main branch OR manual

### 🚀 Complete Zero-Touch Deployment Flow

**No local commands needed - everything runs in GitHub Actions!**

#### Step 1: Configure GitHub Secrets
```
1. Go to repo Settings → Secrets → Actions
2. Add:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_ROLE_ARN (for OIDC, optional)
```

#### Step 2: Bootstrap S3 Backend
```
1. Actions → "Bootstrap S3 Backend" → Run workflow
2. Enter bucket name (must be globally unique)
3. Type "create" to confirm
4. Wait ~1 minute ✅
```

#### Step 3: Configure DNS (One-Time Setup)
```
1. Manually create Route53 hosted zone in AWS Console:
   - Go to Route53 → Create hosted zone
   - Domain: valkov.cloud
2. Copy the 4 nameservers from Route53
3. Update nameservers in Namecheap:
   - Go to Namecheap → Domain List → Manage
   - Select "Custom DNS" and add all 4 nameservers
4. Wait 5-60 minutes for DNS propagation ✅
```

#### Step 4: Configure Manual Approval (Optional but Recommended)
```
1. Go to Settings → Environments → New environment
2. Create environment: "dev"
3. Enable "Required reviewers" and add your GitHub username
4. This adds manual approval before infrastructure changes are applied
5. See docs/MANUAL_APPROVAL_SETUP.md for detailed setup
```

#### Step 5: Deploy Infrastructure
```
1. Actions → "Deploy Infrastructure" → Run workflow
2. Select Environment: dev
3. Workflow runs Terraform Plan automatically (~5 min)
4. Review the plan output in the logs
5. Click "Review deployments" → "Approve and deploy" to proceed
6. Terraform Apply runs (~20 minutes) ✅
7. Certificate will be automatically validated via DNS
```

#### Step 6: Deploy Application
```
1. Actions → "Deploy Application" → Run workflow
   (or just push to main branch)
2. Wait ~5 minutes ✅
3. Visit https://showcase.valkov.cloud → See your app running! 🎉
   (HTTP traffic automatically redirects to HTTPS)
```

#### Cleanup (When Done)
```
1. Actions → "Destroy Infrastructure" → Run workflow
2. Select:
   - Environment: dev
   - Confirm Destroy: DESTROY
3. Wait ~15 minutes ✅
4. All resources deleted!
```

### 📚 Detailed Documentation

See **[GITHUB_ACTIONS_AUTOMATION.md](docs/GITHUB_ACTIONS_AUTOMATION.md)** for:
- Complete setup guide
- Workflow details and options
- Safety features and confirmations
- Troubleshooting steps
- AWS IAM policy examples
- Best practices

### 🔐 Authentication Options

**Option 1: AWS Access Keys** (used by Terraform Management workflows)
- Simple setup
- Store in GitHub Secrets
- Used by terraform-deploy.yml and terraform-destroy.yml
- Good for demos and testing

**Option 2: GitHub OIDC** (used by Deploy Application workflow)
- No long-lived credentials
- More secure
- Used by deploy.yml for ECR authentication
- Recommended for production
- See [GITHUB_ACTIONS_AUTOMATION.md](docs/GITHUB_ACTIONS_AUTOMATION.md) for setup details

### ✅ Safety Features

All workflows include multiple safety features:
- ✅ **Manual Approval** - Engineer reviews plan before apply (see [MANUAL_APPROVAL_SETUP.md](docs/MANUAL_APPROVAL_SETUP.md))
- ✅ **Plan Before Apply** - Always review changes first
- ✅ **Two-Step Deployment** - Plan runs automatically, Apply requires approval
- ✅ **Multiple Confirmations** - Especially for destroy operations
- ✅ **10-Second Countdown** - Before destructive operations
- ✅ **Detailed Logs** - Full visibility into operations
- ✅ **State Locking** - Prevent concurrent modifications
- ✅ **Audit Trail** - GitHub records who approved each deployment

## 🧪 Testing Fail-Over Scenarios

See [FAILOVER_DEMO.md](./docs/FAILOVER_DEMO.md) for detailed fail-over testing procedures.

### Quick Tests

1. **Container Fail-Over**:
   ```bash
   # Stop a running task
   aws ecs stop-task --cluster devops-showcase-dev-cluster --task <task-id>
   ```
   Watch ECS automatically start a replacement task.

2. **Auto-Scaling**:
   ```bash
   # Generate load with Apache Bench
   ab -n 10000 -c 100 https://showcase.valkov.cloud/
   # Or use ALB DNS directly:
   ab -n 10000 -c 100 http://<alb-dns-name>/
   ```
   Monitor CloudWatch to see new tasks being launched.

3. **Database Fail-Over** (Multi-AZ):
   ```bash
   # Force failover to standby instance
   aws rds reboot-db-instance \
     --db-instance-identifier devops-showcase-dev-db \
     --force-failover
   ```
   Application should maintain connectivity during the fail-over.

## 📊 Monitoring

### CloudWatch Dashboards

- **ECS Cluster**: CPU, memory, running tasks
- **ALB**: Request count, target health, response times
- **RDS**: Connections, CPU, storage, replication lag

Access in AWS Console: **CloudWatch** → **Container Insights** → **ECS**

### Logs

View application logs:

```bash
aws logs tail /ecs/devops-showcase-dev-app --follow
```

## 💰 Cost Estimation

Approximate monthly costs (eu-central-1):

| Resource | Configuration | Est. Monthly Cost |
|----------|--------------|-------------------|
| ECS EC2 (2× t3.small) | On-Demand | ~$30 |
| RDS (db.t3.micro Multi-AZ) | On-Demand | ~$30 |
| Application Load Balancer | Standard | ~$20 |
| fck-nat Instance (t4g.micro) | Spot pricing | ~$2-3 |
| Data Transfer | 10 GB/month | ~$1 |
| **Total** | | **~$83-84/month** |

### Cost Optimization Tips

**Current Configuration:**
- ✅ **fck-nat** instead of NAT Gateway (saves **~$29/month** vs single NAT Gateway, **~$61/month** vs Multi-AZ NAT!)
  - Uses [terraform-aws-fck-nat](https://github.com/RaJiska/terraform-aws-fck-nat) module
  - Runs on t4g.micro spot instance (~$2-3/month vs $32/month NAT Gateway)
  - Provides same functionality as AWS NAT Gateway at fraction of cost
  - Perfect for dev/test environments
- ⚠️ Note: Single-AZ fck-nat deployment means no NAT redundancy across AZs (acceptable for dev/staging)

**Additional Optimizations:**

1. **Use RDS Single-AZ** (development only):
   ```hcl
   db_multi_az = false
   ```
   Saves ~$15/month

2. **Use AWS Free Tier** (first 12 months):
   - 750 hours/month t2.micro RDS
   - 750 hours/month t2.micro EC2

### Why fck-nat?

This project uses **[fck-nat](https://github.com/AndrewGuenther/fck-nat)** instead of AWS NAT Gateway for massive cost savings:

**Cost Comparison:**
- AWS NAT Gateway (Single-AZ): **$32/month** + data processing fees
- AWS NAT Gateway (Multi-AZ): **$64/month** + data processing fees
- fck-nat (t4g.micro spot): **$2-3/month** (no data processing fees!)

**Benefits:**
- ✅ **90%+ cost reduction** compared to AWS NAT Gateway
- ✅ **Same functionality** - routes private subnet traffic to internet
- ✅ **ARM-based** (t4g.micro) for better price/performance
- ✅ **Spot instances** for additional savings
- ✅ **Battle-tested** - widely used in production environments
- ✅ **Easy management** via [terraform-aws-fck-nat](https://github.com/RaJiska/terraform-aws-fck-nat) module

**Implementation:**
```hcl
module "fck-nat" {
  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"
  
  name      = "${local.name_prefix}-fck-nat"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]
  
  update_route_tables = true
  route_tables_ids    = local.all_route_tables  # Private + Database subnets
}
```

**Perfect for:** Development, staging, and cost-sensitive production environments.

## 🧹 Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

⚠️ **Warning**: This will permanently delete all resources including the database!

## 📁 Project Structure

```
devops_showcase/
├── app/                          # Node.js application
│   ├── server.js                 # Express application
│   ├── package.json              # Dependencies
│   ├── Dockerfile                # Multi-stage Docker build
│   └── .env.example              # Environment variables template
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Main configuration
│   ├── dns.tf                    # Route53 and ACM certificate
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── providers.tf              # Provider configuration
│   ├── iam.tf                    # IAM roles and policies
│   ├── github-oidc.tf            # GitHub OIDC provider (community module)
│   ├── secrets.tf                # Database password generation
│   ├── user_data.sh              # ECS instance initialization
│   └── environments/             # Environment configurations
│       ├── dev.tfvars            # Development
│       ├── staging.tfvars        # Staging
│       └── prod.tfvars           # Production
├── .github/
│   └── workflows/
│       ├── bootstrap.yml         # Create S3 backend bucket
│       ├── terraform-deploy.yml  # Deploy infrastructure (plan/apply)
│       ├── terraform-destroy.yml # Destroy infrastructure
│       └── deploy.yml            # Build and push to ECR
├── docs/                         # Additional documentation
│   ├── ARCHITECTURE.md           # Detailed architecture
│   ├── DEPLOYMENT.md             # Deployment guide
│   ├── FAILOVER_DEMO.md          # Fail-over testing
│   ├── GITHUB_ACTIONS_AUTOMATION.md  # Complete GitHub Actions guide
│   └── GITHUB_ACTIONS_QUICKSTART.md # 5-minute quick start
├── scripts/                      # Optional local scripts
│   └── bootstrap-backend.sh      # Create S3 bucket (optional)
├── CHANGELOG.md                  # Version history and changes
├── PROJECT_STRUCTURE.md          # Detailed project structure
├── TERRAFORM_MODULE_UPDATES.md   # Module update documentation
└── README.md                     # This file
```

## 🔐 Security Considerations

1. **Database Password**: Auto-generated and stored in AWS Parameter Store
2. **HTTPS**: ✅ Implemented with ACM certificate and automatic HTTP→HTTPS redirect
3. **SSL/TLS**: Free AWS Certificate Manager certificate with automatic renewal
4. **DNS Security**: DNSSEC can be enabled on Route53 for additional protection
5. **Network**: Private subnets for ECS and RDS
6. **IAM**: Least privilege roles for all resources
7. **Secrets**: Never commit sensitive data to Git
8. **Security Groups**: Minimal ingress rules (ports 80, 443 for ALB only)

## 🛠️ Troubleshooting

### ECS Tasks Not Starting

```bash
# Check service events
aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service

# Check task logs
aws logs tail /ecs/devops-showcase-dev-app --follow
```

### Database Connection Issues

1. Verify security group allows traffic from ECS
2. Check RDS endpoint in task definition
3. Confirm database credentials are correct

### ALB Health Checks Failing

1. Ensure container is listening on correct port (3000)
2. Check `/health` endpoint returns 200
3. Review health check configuration in target group

## 🤝 Contributing

This is a showcase project for learning purposes. Feel free to fork and customize!

## 📝 License

MIT License - feel free to use this for learning and demonstration purposes.

## 📚 Additional Resources

- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**Questions or Issues?** Check the [Troubleshooting](#-troubleshooting) section or open an issue on GitHub.

Built with ❤️ for DevOps demonstrations
