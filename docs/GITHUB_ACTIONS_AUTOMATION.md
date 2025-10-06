# GitHub Actions Automation Guide

This guide explains how to use GitHub Actions workflows to automate the complete deployment and management of the DevOps Showcase infrastructure without running any commands locally.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Workflows](#workflows)
  - [1. Bootstrap S3 Backend](#1-bootstrap-s3-backend)
  - [2. Deploy Infrastructure](#2-deploy-infrastructure)
  - [3. Destroy Infrastructure](#3-destroy-infrastructure)
  - [4. Deploy Application to ECR](#4-deploy-application-to-ecr)
- [Complete Deployment Flow](#complete-deployment-flow)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)

## Overview

The project includes four main GitHub Actions workflows that automate everything:

1. **Bootstrap** - Creates S3 bucket for Terraform state storage
2. **Deploy Infrastructure** - Deploys infrastructure (plan/apply)
3. **Destroy Infrastructure** - Destroys all resources (with safety confirmations)
4. **Deploy Application** - Builds and pushes Docker image to ECR

**Key Benefits:**
- ✅ No local commands needed - everything runs in GitHub Actions
- ✅ Secure credential management via GitHub Secrets
- ✅ Built-in validation and confirmation steps
- ✅ Detailed logs and summaries
- ✅ Safe destroy operations with multiple confirmations

## Prerequisites

Before using the workflows, ensure you have:

1. **AWS Account** with appropriate permissions
2. **GitHub Repository** with this code
3. **AWS IAM User** with programmatic access (or OIDC role)

### Required AWS Permissions

The IAM user/role needs permissions for:
- S3 (bucket creation, object management)
- VPC (create/delete VPCs, subnets, route tables, etc.)
- EC2 (instances, security groups, key pairs)
- ECS (clusters, services, task definitions)
- ECR (repositories, images)
- RDS (databases, subnet groups, parameter groups)
- ALB (load balancers, target groups, listeners)
- IAM (roles, policies for ECS tasks)
- CloudWatch (log groups)

See [AWS IAM Policy Example](#aws-iam-policy-example) below for a complete policy.

## GitHub Secrets Configuration

### Required Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

#### Option 1: AWS Access Keys (Recommended for this guide)

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

#### Option 2: AWS OIDC (More secure, no long-lived credentials)

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ROLE_ARN` | ARN of IAM role to assume | `arn:aws:iam::123456789012:role/github-actions-role` |

### How to Create AWS Access Keys

1. Sign in to AWS Console
2. Navigate to IAM → Users
3. Select your user (or create new user)
4. Go to "Security credentials" tab
5. Click "Create access key"
6. Choose "Command Line Interface (CLI)"
7. Download the credentials
8. Add them as GitHub secrets

⚠️ **Security Best Practice:** Use OIDC instead of long-lived access keys when possible.

## Workflows

### 1. Bootstrap S3 Backend

**File:** `.github/workflows/bootstrap.yml`

**Purpose:** Creates an S3 bucket to store Terraform state files with proper security configurations.

**When to Run:** Once, before first infrastructure deployment.

#### Usage

1. Go to GitHub → Actions → "Bootstrap S3 Backend"
2. Click "Run workflow"
3. Configure inputs:
   - **Bucket Name:** Unique S3 bucket name (e.g., `devops-showcase-terraform-state`)
   - **AWS Region:** Choose region (default: `eu-central-1`)
   - **Confirm:** Type `create` to confirm
4. Click "Run workflow"

#### What It Does

- ✅ Creates S3 bucket with unique name
- ✅ Enables versioning (for state history)
- ✅ Enables encryption (AES256)
- ✅ Blocks public access
- ✅ Configures lifecycle policy (delete old versions after 90 days)
- ✅ Adds appropriate tags
- ✅ Generates backend configuration file

#### Output

The workflow creates a `terraform/backend.tf` file with:

```hcl
terraform {
  backend "s3" {
    bucket  = "your-bucket-name"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
```

**Next Step:** Commit this file to your repository or update `terraform/providers.tf` with the backend configuration.

---

### 2. Deploy Infrastructure

**File:** `.github/workflows/terraform-deploy.yml`

**Purpose:** Deploy and update infrastructure with Terraform (plan and apply operations).

**When to Run:** 
- After bootstrap (for first deployment)
- Whenever you want to deploy or update infrastructure
- To preview changes before applying

#### Usage

1. Go to GitHub → Actions → "Deploy Infrastructure"
2. Click "Run workflow"
3. Configure inputs:
   - **Terraform Action:**
     - `plan` - Preview changes (safe, no modifications)
     - `apply` - Deploy infrastructure (creates resources)
   - **Environment:** Choose `dev`, `staging`, or `prod`
   - **Confirmation:**
     - For `apply`: Type `yes`
4. Click "Run workflow"

#### Actions Explained

##### Plan (Safe Preview)
```
Action: plan
Confirmation: Not required
```

- Shows what Terraform will create/modify/destroy
- No actual changes made
- Use this to review changes before applying
- Duration: ~2-3 minutes

##### Apply (Deploy Infrastructure)
```
Action: apply
Confirmation: Type "yes"
```

- Creates all AWS resources:
  - VPC with public/private subnets
  - Application Load Balancer
  - ECS cluster and service
  - RDS PostgreSQL database
  - ECR repository
  - Security groups and IAM roles
- Takes 15-20 minutes
- Outputs ALB DNS name and other resource details

#### Workflow Stages

The workflow has three jobs that run in sequence:

```
1. validate-inputs
   └─> Checks confirmation field
   
2. terraform-plan
   └─> Creates execution plan
   └─> Saves plan as artifact
   
3. terraform-apply (if action = apply)
   └─> Applies the plan
   └─> Shows deployment summary
```

#### Output

After successful `apply`, you'll see:

```
╔════════════════════════════════════════════════════════════╗
║              Deployment Successful! 🎉                     ║
╚════════════════════════════════════════════════════════════╝

Environment: dev
Region: eu-central-1

🌐 Application URL: http://devops-showcase-dev-alb-123456789.eu-central-1.elb.amazonaws.com
📦 ECR Repository: 123456789012.dkr.ecr.eu-central-1.amazonaws.com/devops-showcase-dev

📋 Next Steps:
   1. Build and push Docker image to ECR
   2. Run the 'Deploy Application' workflow
   3. Visit the application URL in your browser
```

---

### 3. Destroy Infrastructure

**File:** `.github/workflows/terraform-destroy.yml`

**Purpose:** Safely destroy all infrastructure resources.

**When to Run:** 
- When you want to completely remove all AWS resources
- To save costs when infrastructure is not needed
- End of demo or testing

⚠️ **WARNING:** This workflow is destructive and irreversible!

#### Usage

1. Go to GitHub → Actions → "Destroy Infrastructure"
2. Click "Run workflow"
3. Configure inputs:
   - **Environment:** Choose `dev`, `staging`, or `prod`
   - **Confirm Destroy:** Type `DESTROY` (all caps)
4. Click "Run workflow"

#### What It Does

- ⚠️ **WARNING:** This is irreversible!
- Deletes ALL resources including:
  - Database (all data lost!)
  - Load balancer
  - ECS cluster
  - VPC and networking
  - ECR images
- Includes safety confirmations
- 10-second countdown before destruction

#### Workflow Stages

The workflow has two jobs that run in sequence:

```
1. validate-destroy
   └─> Checks confirmation field (must be "DESTROY")
   
2. terraform-destroy
   └─> Creates destroy plan
   └─> Shows resources to be destroyed
   └─> 10-second warning countdown
   └─> Executes destruction
   └─> Cleans up ECR images
```

#### Safety Features

1. **Confirmation Required:** Must type "DESTROY" (all caps) to proceed
2. **Destroy Plan:** Reviews all resources to be deleted
3. **10-Second Countdown:** Final warning before destruction
4. **Manual Trigger Only:** Cannot be accidentally triggered
5. **ECR Cleanup:** Automatically removes container images

#### Output

After successful destroy:

```
╔════════════════════════════════════════════════════════════╗
║              Infrastructure Destroyed 💥                   ║
╚════════════════════════════════════════════════════════════╝

Environment: dev
Region: us-east-1

✅ All resources have been destroyed
✅ ECR images cleaned up

The infrastructure has been completely removed.

📋 Optional Next Steps:
   • Delete S3 state bucket if no longer needed
   • Review AWS Console to confirm all resources are gone
   • Check for any remaining resources that may incur charges
```

---

### 4. Deploy Application to ECR

**File:** `.github/workflows/deploy.yml`

**Purpose:** Builds Docker image and pushes to ECR (existing workflow).

**When to Run:** After infrastructure is deployed.

This workflow runs automatically on push to main branch, or can be triggered manually.

---

## Complete Deployment Flow

### First Time Setup (Full Deployment)

Follow these steps in order:

#### Step 1: Configure GitHub Secrets
```
1. Go to GitHub repo → Settings → Secrets → Actions
2. Add secrets:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
```

#### Step 2: Bootstrap S3 Backend
```
1. Actions → "Bootstrap S3 Backend" → Run workflow
2. Inputs:
   - Bucket Name: devops-showcase-terraform-state-UNIQUE
   - Region: eu-central-1
   - Confirm: create
3. Wait ~1 minute
4. Verify: Check S3 console for new bucket
```

#### Step 3: Deploy Infrastructure
```
1. Actions → "Deploy Infrastructure" → Run workflow
2. Inputs:
   - Action: apply
   - Environment: dev
   - Confirm Apply: yes
3. Wait ~20 minutes
4. Copy ALB DNS from output
```

#### Step 4: Deploy Application
```
1. Actions → "Deploy Application" → Run workflow (or push to main)
2. Wait ~5 minutes
3. Visit ALB DNS in browser
4. See application running! 🎉
```

### Updates and Changes

To update infrastructure:

```
1. Modify Terraform files
2. Commit and push changes
3. Run "Deploy Infrastructure"
   - Action: plan (review changes)
4. Run again with Action: apply
   - Confirm Apply: yes
```

### Cleanup (Destroy Everything)

When you're done:

```
1. Actions → "Destroy Infrastructure" → Run workflow
2. Inputs:
   - Environment: dev
   - Confirm Destroy: DESTROY
3. Wait ~15 minutes
4. Verify: Check AWS console - resources should be gone
```

**Optional:** Manually delete S3 state bucket if no longer needed.

---

## Safety Features

### Built-in Protections

#### 1. Input Validation
- Apply requires typing `yes`
- Destroy requires typing `DESTROY` (all caps)
- Wrong confirmation = workflow fails immediately

#### 2. Plan Before Action
- Every apply/destroy runs plan first
- Review changes in plan output
- Plan saved as artifact (7-day retention)

#### 3. Environment Protection
- Uses GitHub Environments feature
- Can add required reviewers
- Can add wait timers

#### 4. Destroy Safeguards
- Multiple confirmation steps
- 10-second countdown with warning
- Manual trigger only (no automatic destroy)
- Clear warning about data loss

#### 5. State Locking
- S3 native state locking prevents concurrent modifications
- No DynamoDB required

### Recommended Additional Protections

#### Add Environment Protection Rules

1. Go to Settings → Environments → dev
2. Add protection rules:
   - ✅ Required reviewers (for production)
   - ✅ Wait timer (e.g., 5 minutes)
   - ✅ Deployment branches (restrict to main)

#### Use Branch Protection

1. Settings → Branches → Add rule
2. Protect `main` branch:
   - ✅ Require pull request reviews
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date

---

## Troubleshooting

### Common Issues

#### ❌ Error: "Context access might be invalid: AWS_ACCESS_KEY_ID"

**Cause:** GitHub secret not configured

**Solution:**
```
1. Go to repo Settings → Secrets → Actions
2. Add AWS_ACCESS_KEY_ID secret
3. Add AWS_SECRET_ACCESS_KEY secret
4. Re-run workflow
```

#### ❌ Error: "Bucket already exists"

**Cause:** S3 bucket name must be globally unique

**Solution:**
```
1. Add unique suffix to bucket name
2. Example: devops-showcase-tf-state-YOUR-GITHUB-USERNAME
3. Re-run bootstrap workflow
```

#### ❌ Error: "InvalidAccessKeyId"

**Cause:** Incorrect AWS credentials

**Solution:**
```
1. Verify credentials in AWS IAM console
2. Create new access key if needed
3. Update GitHub secrets
4. Ensure IAM user has required permissions
```

#### ❌ Terraform Plan Shows No Changes (but resources exist)

**Cause:** State file out of sync

**Solution:**
```
1. Check S3 bucket for state file
2. Verify backend configuration in providers.tf
3. Run: terraform init -reconfigure (locally or in workflow)
4. Consider importing existing resources
```

#### ❌ Error: "Insufficient permissions"

**Cause:** IAM user/role lacks required permissions

**Solution:**
```
1. Review IAM policy (see below)
2. Attach necessary permissions
3. Wait a few minutes for propagation
4. Re-run workflow
```

#### ❌ Terraform Apply Takes Too Long / Times Out

**Cause:** RDS creation is slow, or other resource delays

**Solution:**
```
- This is normal! RDS Multi-AZ takes 15-20 minutes
- Check CloudWatch logs for progress
- Workflow timeout is set to 60 minutes
- If timeout occurs, re-run the workflow
```

#### ❌ ECR Push Fails

**Cause:** ECR repository not created yet, or authentication issue

**Solution:**
```
1. Ensure infrastructure is deployed first
2. Check ECR repository exists in AWS console
3. Verify AWS credentials have ECR permissions
4. Re-run deploy workflow
```

### Debugging Steps

#### 1. Check Workflow Logs
```
1. Go to Actions tab
2. Click on failed workflow run
3. Expand each step to see detailed logs
4. Look for error messages
```

#### 2. Verify AWS Console
```
1. Sign in to AWS Console
2. Check resources in:
   - VPC
   - EC2 (instances, load balancers)
   - ECS (clusters, services)
   - RDS (databases)
   - S3 (state bucket)
3. Verify resources match Terraform plan
```

#### 3. Check Terraform State
```
1. Download state from S3:
   aws s3 cp s3://your-bucket/terraform.tfstate .
2. Review state file (JSON format)
3. Verify resources match AWS console
```

#### 4. Local Terraform Debug (if needed)
```bash
# Clone repo and configure backend
git clone <your-repo>
cd devops_showcase/terraform

# Initialize with S3 backend
terraform init

# Check state
terraform state list

# View specific resource
terraform state show <resource-name>

# Refresh state
terraform refresh
```

---

## AWS IAM Policy Example

Complete IAM policy for Terraform operations:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StateManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutBucketTagging",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::devops-showcase-*",
        "arn:aws:s3:::devops-showcase-*/*"
      ]
    },
    {
      "Sid": "VPCManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:*Vpc*",
        "ec2:*Subnet*",
        "ec2:*Gateway*",
        "ec2:*Route*",
        "ec2:*SecurityGroup*",
        "ec2:*NetworkAcl*",
        "ec2:*NetworkInterface*",
        "ec2:Describe*",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSManagement",
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSManagement",
      "Effect": "Allow",
      "Action": [
        "rds:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ALBManagement",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMManagement",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:PassRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:GetInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScaling",
      "Effect": "Allow",
      "Action": [
        "autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Note:** This is a broad policy for ease of use. In production, restrict to specific resources using conditions and resource ARNs.

---

## Workflow Comparison

| Feature | Bootstrap | Deploy Infra | Destroy Infra | Deploy App |
|---------|-----------|--------------|---------------|------------|
| **Trigger** | Manual only | Manual only | Manual only | Push/Manual |
| **Purpose** | Create S3 bucket | Deploy infra | Destroy infra | Build/push Docker |
| **Auth** | AWS Keys | AWS Keys | AWS Keys | AWS Keys or OIDC |
| **Confirmation** | "create" | "yes" | "DESTROY" | None |
| **Duration** | ~1 minute | 15-20 minutes | 10-15 minutes | ~5 minutes |
| **Run Once?** | Yes | No (repeatable) | No (repeatable) | No (repeatable) |
| **Idempotent?** | Yes | Yes | Yes | Yes |

---

## Best Practices

### 1. Always Run Plan First
```
Before apply, run with action: plan
Review the output carefully
Then run with action: apply
```

### 2. Use Descriptive Commit Messages
```bash
git commit -m "feat: add CloudWatch alarms"
git commit -m "fix: increase ECS desired count to 3"
git commit -m "chore: update Terraform to 1.6.0"
```

### 3. Tag Your Infrastructure
- All resources automatically tagged via `terraform.tfvars`
- Tags help with cost tracking and resource management

### 4. Monitor Costs
```
- Set up AWS Billing Alerts
- Review costs in AWS Cost Explorer
- Free tier resources may incur charges after limits
```

### 5. Backup Important Data
```
- RDS automated backups enabled (7 days)
- S3 versioning keeps state file history (90 days)
- Export data before destroying infrastructure
```

### 6. Use Pull Requests
```
1. Create feature branch
2. Make Terraform changes
3. Open PR for review
4. Run plan workflow on PR
5. Merge after approval
6. Run apply on main branch
```

### 7. Environment Isolation
```
dev → Quick tests, frequent changes
staging → Pre-production validation
prod → Production workloads (add extra protections)
```

---

## Frequently Asked Questions

### Q: Can I run multiple environments simultaneously?

**A:** Yes! Each environment is isolated. Run the workflow with different environment inputs:
```
Environment: dev    → Creates devops-showcase-dev-*
Environment: staging → Creates devops-showcase-staging-*
Environment: prod    → Creates devops-showcase-prod-*
```

### Q: How much will this cost?

**A:** Estimated costs for `dev` environment (24/7 running):
- RDS db.t3.micro: ~$15/month
- EC2 t3.small (2 instances): ~$30/month
- ALB: ~$16/month
- Data transfer: ~$5/month
- **Total: ~$66/month**

Free tier offsets some costs for first 12 months.

### Q: Can I stop/start resources to save costs?

**A:** Yes, but requires additional configuration:
```
- Stop RDS instance manually (not deleted)
- Scale ECS service to 0 desired tasks
- Or destroy infrastructure when not needed
```

### Q: What if I need to modify Terraform code?

**A:** Standard Git workflow:
```
1. Clone repo
2. Create branch
3. Modify .tf files
4. Commit and push
5. Open PR
6. After merge, run workflow with action: apply
```

### Q: Can I use this in production?

**A:** This is a demo project, but with enhancements:
- ✅ Use OIDC instead of access keys
- ✅ Add environment protection rules
- ✅ Enable CloudTrail for audit logs
- ✅ Set up monitoring and alerts
- ✅ Use separate AWS accounts per environment
- ✅ Store secrets in AWS Secrets Manager
- ✅ Enable VPC Flow Logs
- ✅ Implement backup strategies
- ✅ Add disaster recovery procedures

### Q: How do I roll back a failed deployment?

**A:** Terraform doesn't have built-in rollback, but:
```
1. Revert commit in Git
2. Run workflow with action: apply
3. Terraform will reconcile to previous state
```

Or:
```
1. Restore previous state file from S3 versions
2. Run terraform apply
```

### Q: What happens if workflow fails mid-deployment?

**A:** Terraform state is consistent:
```
- Partial resources may exist
- State file reflects what was created
- Re-run workflow to continue
- Or run destroy to clean up
```

---

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs
3. Check AWS CloudWatch logs
4. Review project documentation in `docs/` directory

---

**Last Updated:** October 2025

**Version:** 1.0
