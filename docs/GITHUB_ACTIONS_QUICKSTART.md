# GitHub Actions Quick Reference

**Zero Local Commands - Complete Cloud Automation!**

## 🎯 Quick Links

- **Full Guide:** [GITHUB_ACTIONS_AUTOMATION.md](./GITHUB_ACTIONS_AUTOMATION.md)
- **Main README:** [README.md](../README.md)
- **Architecture:** [ARCHITECTURE.md](./ARCHITECTURE.md)

## 🚀 5-Minute Deployment

### Prerequisites
1. GitHub repository with this code
2. AWS account
3. AWS Access Key & Secret Key

### Steps

#### 1. Configure Secrets (2 minutes)
```
GitHub Repo → Settings → Secrets → Actions → New secret
Add:
  - AWS_ACCESS_KEY_ID = your-access-key
  - AWS_SECRET_ACCESS_KEY = your-secret-key
```

#### 2. Bootstrap S3 Backend (1 minute)
```
Actions → "Bootstrap S3 Backend" → Run workflow
  Bucket Name: devops-showcase-tf-state-YOURNAME
  Region: eu-central-1
  Confirm: create
```

#### 3. Deploy Infrastructure (20 minutes)
```
Actions → "Deploy Infrastructure" → Run workflow
  Action: apply
  Environment: dev
  Confirm Apply: yes
```

#### 4. Deploy Application (5 minutes)
```
Actions → "Deploy Application" → Run workflow
OR
Just push to main branch (auto-triggers)
```

#### 5. Access Application (0 minutes)
```
Check workflow output for ALB DNS
Open: http://devops-showcase-dev-alb-XXXXXX.eu-central-1.elb.amazonaws.com
```

**Total Time: ~26 minutes** ⏱️

---

## 📋 Workflow Cheat Sheet

### Bootstrap S3 Backend
```yaml
Workflow: bootstrap.yml
Trigger: Manual only
Duration: ~1 minute
Inputs:
  - bucket_name: Unique S3 bucket name
  - aws_region: eu-central-1 (default)
  - confirm: Type "create"
Run Once: Yes (first time only)
```

### Deploy Infrastructure
```yaml
Workflow: terraform-deploy.yml
Trigger: Manual only
Duration: 15-20 minutes
Inputs:
  - action: plan | apply
  - environment: dev | staging | prod
  - confirm_apply: Type "yes" for apply
Repeatable: Yes
```

### Destroy Infrastructure
```yaml
Workflow: terraform-destroy.yml
Trigger: Manual only
Duration: 10-15 minutes
Inputs:
  - environment: dev | staging | prod
  - confirm_destroy: Type "DESTROY"
Repeatable: Yes
```

### Deploy Application
```yaml
Workflow: deploy.yml
Trigger: Push to main OR manual
Duration: ~5 minutes
No inputs required
Uses: OIDC authentication (AWS_ROLE_ARN secret)
```

---

## 🎬 Common Workflows

### First Deployment
```
1. Bootstrap → 2. Apply → 3. Deploy App
```

### Update Infrastructure
```
1. Modify .tf files
2. Push to GitHub
3. Run workflow: action=plan (review)
4. Run workflow: action=apply
```

### Update Application
```
1. Modify app/server.js
2. Push to main branch
3. Workflow auto-runs
4. New image deployed
```

### Complete Cleanup
```
1. Actions → "Destroy Infrastructure" → Run workflow
2. Enter: confirm=DESTROY
3. (Optional) Delete S3 state bucket manually
```

---

## ⚡ Actions & Confirmations

| Action | Confirmation Required | Destructive? | Duration |
|--------|---------------------|--------------|----------|
| **plan** | None | ❌ No | 2-3 min |
| **apply** | Type "yes" | ⚠️ Creates resources | 15-20 min |
| **destroy** | Type "DESTROY" | 💥 Deletes everything | 10-15 min |
| **bootstrap** | Type "create" | ❌ No | 1 min |

---

## 🔐 Required Secrets

### For Terraform Workflows (bootstrap.yml, terraform-manage.yml)
```
AWS_ACCESS_KEY_ID = AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE
```

### For Deploy Workflow (deploy.yml)
```
AWS_ROLE_ARN = arn:aws:iam::123456789012:role/github-actions-role
```
*Note: OIDC role is created automatically when you deploy infrastructure*

---

## 🛡️ Safety Features

| Feature | Description |
|---------|-------------|
| **Input Validation** | Wrong confirmation = workflow fails |
| **Plan First** | Always runs plan before apply/destroy |
| **Artifact Save** | Plans saved for 7 days |
| **State Locking** | S3 native locking prevents conflicts |
| **Manual Triggers** | No accidental deployments |
| **10-Second Countdown** | Before destroy operations |
| **Multiple Confirmations** | Type exact phrases to proceed |

---

## 💡 Tips & Tricks

### Preview Changes Before Apply
```
1. Run with action: plan
2. Review output carefully
3. If good, run with action: apply
```

### Multiple Environments
```
Run workflow 3 times with different environments:
  - Environment: dev
  - Environment: staging
  - Environment: prod

Each creates isolated resources:
  - devops-showcase-dev-*
  - devops-showcase-staging-*
  - devops-showcase-prod-*
```

### Cost Savings
```
When not using infrastructure:
  Action: destroy
  Confirm: DESTROY
  
Redeploy later:
  Action: apply
  Confirm: yes
```

### Emergency Stop
```
If workflow is stuck:
1. Click "Cancel workflow" in GitHub
2. Check AWS console
3. Run destroy if needed
```

---

## 📊 Workflow Outputs

### After Bootstrap
```
✅ S3 bucket created: devops-showcase-tf-state-yourname
✅ Versioning enabled
✅ Encryption configured
✅ Backend config file generated
```

### After Apply
```
🌐 Application URL: http://alb-dns-name.amazonaws.com
📦 ECR Repository: 123456789012.dkr.ecr.eu-central-1.amazonaws.com/repo
🗄️ Database Endpoint: db.xxxxxx.eu-central-1.rds.amazonaws.com
🔐 GitHub Actions Role: arn:aws:iam::123456789012:role/github-actions-role
```

### After Destroy
```
✅ All resources destroyed
✅ ECR images cleaned up
✅ Infrastructure completely removed
```

---

## 🚨 Troubleshooting Quick Fixes

### Error: "Bucket already exists"
```
Solution: Add unique suffix to bucket name
Example: devops-showcase-tf-state-yourname-123
```

### Error: "InvalidAccessKeyId"
```
Solution: 
1. Check secrets in GitHub
2. Verify credentials in AWS IAM
3. Create new access key if needed
```

### Error: "Insufficient permissions"
```
Solution:
1. Check IAM user permissions
2. Attach AdministratorAccess (for demo)
3. Or use specific policies from docs
```

### Workflow: "Plan shows no changes but resources exist"
```
Solution:
1. Check S3 for state file
2. Verify backend config in providers.tf
3. Run: terraform init -reconfigure
```

### Apply: "Takes too long / times out"
```
This is normal! RDS Multi-AZ takes 15-20 minutes
- Check workflow logs for progress
- Timeout is 60 minutes
- If fails, just re-run workflow
```

---

## 📞 Get Help

1. **Check Workflow Logs:** Actions tab → Failed run → Expand steps
2. **AWS Console:** Verify resources match plan
3. **Documentation:** [Full guide](./GITHUB_ACTIONS_AUTOMATION.md)
4. **S3 State:** Download and inspect state file
5. **CloudWatch:** Check application logs

---

## 🎯 Success Checklist

- [ ] GitHub secrets configured
- [ ] S3 bucket created (bootstrap)
- [ ] Infrastructure deployed (apply)
- [ ] Application deployed (push to main)
- [ ] ALB DNS accessible in browser
- [ ] Application shows container info
- [ ] Request counter increments
- [ ] Database connected ✅

---

## 🔗 Related Documentation

- [Full Automation Guide](./GITHUB_ACTIONS_AUTOMATION.md) - Complete reference
- [S3 Backend & OIDC Setup](./S3_BACKEND_OIDC_SETUP.md) - Advanced security
- [Architecture Details](./ARCHITECTURE.md) - Technical deep dive
- [Fail-over Testing](./FAILOVER_DEMO.md) - High availability demos
- [Deployment Guide](./DEPLOYMENT.md) - Step-by-step manual deployment

---

**Last Updated:** October 2025
**Version:** 1.0

**🎉 Happy Automating!** No more local commands needed!
