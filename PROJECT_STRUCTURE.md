# Project Structure

Complete directory structure of the DevOps Showcase project.

```
devops_showcase/
│
├── README.md                          # Main project documentation
├── .gitignore                         # Git ignore rules
├── tasks.txt                          # Original task requirements
│
├── app/                               # Node.js Application
│   ├── server.js                      # Express application code
│   ├── package.json                   # NPM dependencies
│   ├── Dockerfile                     # Multi-stage Docker build
│   ├── .dockerignore                  # Docker build exclusions
│   ├── .env.example                   # Environment variables template
│   └── README.md                      # Application documentation
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                        # Main infrastructure configuration
│   ├── dns.tf                         # Route53 and ACM certificate configuration
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── providers.tf                   # Provider configuration (Terraform >= 1.12.2)
│   ├── iam.tf                         # IAM roles and policies
│   ├── github-oidc.tf                 # GitHub OIDC provider (community module v1.0)
│   ├── secrets.tf                     # Password generation and Parameter Store
│   ├── user_data.sh                   # ECS instance initialization (simplified)
│   ├── terraform.tfvars               # Deprecated (see environments/)
│   ├── environments/                  # Environment-specific configurations
│   │   ├── dev.tfvars                 # Development settings
│   │   ├── staging.tfvars             # Staging settings
│   │   ├── prod.tfvars                # Production settings
│   │   └── README.md                  # Environment documentation
│   └── README.md                      # Terraform documentation (optional)
│
├── .github/                           # GitHub Configuration
│   └── workflows/
│       ├── bootstrap.yml              # Create S3 backend bucket
│       ├── terraform-deploy.yml       # Deploy infrastructure (plan/apply)
│       ├── terraform-destroy.yml      # Destroy infrastructure
│       └── deploy.yml                 # Build and push to ECR
│
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md                # Detailed architecture guide
│   ├── DEPLOYMENT.md                  # Local deployment (legacy)
│   ├── FAILOVER_DEMO.md               # Fail-over testing procedures
│   ├── GITHUB_ACTIONS_AUTOMATION.md   # Complete workflow documentation
│   └── GITHUB_ACTIONS_QUICKSTART.md   # Quick start guide
│
├── scripts/                           # Optional Local Scripts
│   └── bootstrap-backend.sh           # Create S3 bucket (optional)
│
└── MIGRATION.md                       # October 2025 changes explained
```

## Key Files Explained

### Application Layer (`app/`)

- **server.js**: Main Express application
  - Dashboard with infrastructure info
  - Database integration
  - Health check endpoints
  - Auto-scaling counter

- **Dockerfile**: Production-ready container image
  - Multi-stage build
  - Non-root user
  - Health checks
  - Optimized size

- **package.json**: Dependencies and scripts
  - Express web framework
  - PostgreSQL client
  - Development tools

### Infrastructure Layer (`terraform/`)

- **main.tf**: Core infrastructure (using community modules)
  - VPC with multi-AZ subnets (terraform-aws-modules/vpc v6.4.0)
  - ECS cluster with EC2 capacity provider (terraform-aws-modules/ecs v6.6.1)
  - Application Load Balancer with HTTPS (terraform-aws-modules/alb v9.17.0)
  - RDS PostgreSQL Multi-AZ (terraform-aws-modules/rds v6.13.0)
  - Security Groups (terraform-aws-modules/security-group v5.3.0)
  - EC2 Auto Scaling (terraform-aws-modules/autoscaling v9.0.1)
  - ECR repository
  - CloudWatch logging

- **dns.tf**: DNS and SSL/TLS infrastructure
  - Route53 hosted zone (data source - manual creation required)
  - ACM certificate for showcase.valkov.cloud
  - DNS validation records (automatic certificate validation)
  - Route53 A record (alias to ALB)
  - HTTPS listener with HTTP→HTTPS redirect

- **github-oidc.tf**: GitHub Actions authentication
  - Uses terraform-module/github-oidc-provider v1.0
  - Replaces 130+ lines of manual OIDC configuration
  - Automatic thumbprint management
  - Custom deployment IAM policy attached
  - Repository-scoped access control

- **secrets.tf**: Secure password management
  - Auto-generated database passwords
  - AWS Systems Manager Parameter Store integration
  - Secure string encryption

- **environments/**: Environment-specific configurations (NEW)
  - **dev.tfvars**: Development environment settings
  - **staging.tfvars**: Staging environment settings
  - **prod.tfvars**: Production environment settings
  - Separate VPC CIDRs for each environment
  - Different instance sizes per environment
  - No secrets stored (passwords auto-generated)

- **variables.tf**: Variable definitions
  - AWS region (default: eu-central-1)
  - Instance sizes and counts
  - Database configuration
  - Auto-scaling thresholds
  - Health check settings

- **outputs.tf**: Deployment information
  - Application URLs (HTTP and HTTPS)
  - Domain name (showcase.valkov.cloud)
  - ACM certificate ARN
  - Route53 zone ID
  - ECR repository URL
  - Database endpoint
  - Resource ARNs
  - Summary display with DNS instructions

- **iam.tf**: Security roles
  - ECS task execution role
  - ECS task role
  - EC2 instance role (now managed by autoscaling module)
  - Least privilege policies

- **user_data.sh**: ECS instance bootstrap script
  - Simplified heredoc syntax
  - Cluster registration
  - Debug logging enabled
  - Automatic instance tagging
  - Follows terraform-aws-modules/ecs best practices

### CI/CD Layer (`.github/workflows/`)

- **deploy.yml**: GitHub Actions workflow
  - Triggered on push to main
  - Builds Docker image
  - Pushes to ECR
  - Optional ECS update

### Documentation (`docs/`)

- **ARCHITECTURE.md**: Deep technical dive
  - Network architecture
  - Component interactions
  - Design decisions
  - Security architecture
  - Cost analysis

- **DEPLOYMENT.md**: Operational guide
  - Prerequisites
  - Step-by-step deployment
  - Verification procedures
  - Troubleshooting
  - Post-deployment tasks

- **FAILOVER_DEMO.md**: Testing guide
  - Container fail-over
  - Auto-scaling demonstration
  - Database fail-over
  - Load balancer testing
  - Monitoring procedures

### Scripts (`scripts/`)

- **deploy.sh**: Automated deployment
  - Checks prerequisites
  - Deploys infrastructure
  - Builds and pushes image
  - Updates ECS service

- **cleanup.sh**: Safe teardown
  - Confirms destruction
  - Runs terraform destroy
  - Provides cost savings info

## Terraform Community Modules

The project uses official terraform-aws-modules for best practices and maintainability:

| Module | Version | Purpose |
|--------|---------|---------|
| [vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) | ~> 5.21 | Multi-AZ networking with single NAT gateway |
| [ecs/cluster](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws) | ~> 6.6 | ECS cluster with capacity providers |
| [ecs/service](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws) | ~> 6.6 | Service, task definition, autoscaling |
| [alb](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws) | ~> 9.17 | Application Load Balancer with target groups |
| [rds](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws) | ~> 6.13 | PostgreSQL with Multi-AZ support |
| [security-group](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws) | ~> 5.3 | Security groups for ALB, ECS, RDS |
| [autoscaling](https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws) | ~> 9.0 | EC2 Auto Scaling for ECS instances |

**Benefits:**
- ✅ Community-tested and maintained
- ✅ Regular security updates
- ✅ AWS best practices built-in
- ✅ Reduced boilerplate code
- ✅ Better documentation and examples

## File Sizes

Approximate file sizes:

| File | Lines | Purpose |
|------|-------|---------|
| server.js | ~400 | Application logic |
| main.tf | ~480 | Infrastructure definition (reduced from ~650) |
| dns.tf | ~75 | Route53 and ACM certificate configuration |
| variables.tf | ~200 | Configuration parameters |
| outputs.tf | ~120 | Resource outputs (including DNS) |
| iam.tf | ~90 | Security roles (reduced from ~150) |
| secrets.tf | ~60 | Password generation and storage |
| README.md | ~500 | Main documentation |
| ARCHITECTURE.md | ~600 | Technical details |
| DEPLOYMENT.md | ~700 | Deployment guide |
| FAILOVER_DEMO.md | ~600 | Testing procedures |

## Configuration Files

### Essential Configuration

1. **terraform.tfvars** (create from example)
   - Must contain database password
   - Customize instance sizes
   - Set AWS region

2. **.env** (for local development)
   - Database credentials
   - Application port
   - Environment settings

3. **GitHub Secrets** (for CI/CD)
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY

## Generated Files (Not in Git)

These files are created during deployment:

```
terraform/
├── .terraform/                 # Terraform providers and modules
├── .terraform.lock.hcl         # Provider version locks
├── terraform.tfstate           # Current infrastructure state
├── terraform.tfstate.backup    # Previous state backup
└── tfplan                      # Execution plan (temporary)

app/
└── node_modules/               # NPM dependencies

Root:
└── deployment-info.txt         # Saved outputs (optional)
```

## Total Project Size

- **Source Code**: ~3,000 lines
- **Documentation**: ~3,000 lines
- **Configuration**: ~500 lines
- **Total**: ~6,500 lines

## Resource Count

When fully deployed, Terraform creates approximately:

- **Networking**: 20+ resources (VPC, subnets, route tables, NAT gateway)
- **DNS & Certificates**: 4+ resources (Route53 records, ACM certificate, validation)
- **Compute**: 15+ resources (ECS, ASG, launch template, capacity provider)
- **Load Balancing**: 6+ resources (ALB, target groups, HTTP/HTTPS listeners)
- **Database**: 5+ resources (RDS instance, subnet group, parameter group)
- **Security**: 10+ resources (security groups, IAM roles, policies)
- **Monitoring**: 5+ resources (CloudWatch log groups, alarms)
- **Container Registry**: 2+ resources (ECR repository, lifecycle policy)

**Total: 67-77 AWS resources** (Note: Route53 hosted zone created manually)

## Usage Statistics

Typical resource usage:

- **Container Images**: 1-2 GB (in ECR)
- **Application Memory**: 512 MB per task
- **Database Storage**: 20 GB (expandable to 40 GB)
- **Logs**: 1-5 GB/month (with 7-day retention)
- **Network**: 10-50 GB/month (varies with traffic)

## Maintenance Files

Files that require regular updates:

| File | Update Frequency | Reason |
|------|------------------|--------|
| server.js | As needed | Feature additions |
| terraform.tfvars | Rarely | Infrastructure changes |
| deploy.yml | Rarely | CI/CD adjustments |
| README.md | As needed | Documentation updates |
| Dockerfile | Rarely | Base image updates |

## Version Control

Recommended Git workflow:

```
main (production)
└── develop (testing)
    └── feature/* (new features)
```

Protected files (in .gitignore):
- terraform.tfvars
- .env
- *.tfstate
- node_modules/

## Navigation

From any location in the project:

```bash
# View application
cd app && npm start

# Deploy infrastructure
cd terraform && terraform apply

# Read documentation
cd docs && cat ARCHITECTURE.md

# Run deployment
./scripts/deploy.sh

# Check project structure
tree -L 2 -I 'node_modules|.terraform'
```

---

This structure follows best practices for:
- ✅ Infrastructure as Code
- ✅ Separation of concerns
- ✅ Clear documentation
- ✅ Automation-friendly
- ✅ Version control ready
