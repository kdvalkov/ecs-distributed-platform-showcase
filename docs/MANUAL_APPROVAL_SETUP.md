# Manual Approval Setup for Terraform Deployments

This guide explains how to configure **manual approval** for the Terraform deployment workflow, ensuring that an engineer reviews and approves infrastructure changes before they are applied.

## 🎯 Overview

The deployment workflow has been designed with a **two-step approval process**:

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Terraform Plan (Automatic)                         │
│  - Runs automatically when workflow is triggered             │
│  - Shows all infrastructure changes                          │
│  - Uploads plan artifact for next step                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2: Manual Approval (WAIT FOR ENGINEER)                │
│  ⏸️  Workflow pauses here                                    │
│  👤 Engineer reviews the plan                                │
│  ✅ Engineer clicks "Approve and deploy" button              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 3: Terraform Apply (After Approval)                   │
│  - Only runs after manual approval                           │
│  - Uses the saved plan from step 1                           │
│  - Applies infrastructure changes                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Setup Instructions

### Step 1: Create GitHub Environments

You need to create GitHub Environments with protection rules for each deployment environment (dev, staging, prod).

#### Option A: Using GitHub Web UI (Recommended)

1. **Navigate to Repository Settings**
   ```
   Your Repository → Settings → Environments
   ```

2. **Create Environment**
   - Click **"New environment"**
   - Name: `dev` (or `staging`, `prod`)
   - Click **"Configure environment"**

3. **Add Protection Rules**
   
   **Required Reviewers:**
   - Check ☑️ **"Required reviewers"**
   - Click **"Add up to 6 reviewers"**
   - Add your GitHub username (or team members)
   - This ensures someone must approve before apply runs

   **Wait Timer (Optional):**
   - Set **"Wait timer"** to 0 minutes (or add a delay if desired)
   
   **Deployment Branches (Optional):**
   - Select **"Selected branches"** 
   - Add rule: `main` (only allow deployments from main branch)

4. **Save Protection Rules**
   - Click **"Save protection rules"**

5. **Repeat for Other Environments**
   - Create `staging` and `prod` environments
   - Add appropriate reviewers for each

#### Option B: Using GitHub CLI

```bash
# Install GitHub CLI if not already installed
# brew install gh  # macOS
# https://cli.github.com/  # Other platforms

# Authenticate
gh auth login

# Create environments (you'll need to add reviewers via UI)
gh api repos/:owner/:repo/environments/dev -X PUT
gh api repos/:owner/:repo/environments/staging -X PUT
gh api repos/:owner/:repo/environments/prod -X PUT
```

**Note:** GitHub CLI doesn't support adding required reviewers directly. You'll need to add them via the web UI.

### Step 2: Verify Setup

1. **Trigger the Workflow**
   ```
   Actions → Deploy Infrastructure → Run workflow
   Select environment: dev
   ```

2. **Observe the Behavior**
   - ✅ **Terraform Plan** job runs automatically
   - ⏸️ **Approve and Apply** job shows status: **"Waiting"**
   - 📧 You receive an email notification requesting review

3. **Review and Approve**
   - Click on the **"Approve and Apply"** job
   - You'll see: **"Review pending"** with a **"Review deployments"** button
   - Click **"Review deployments"**
   - Select the environment to approve
   - Click **"Approve and deploy"**

4. **Apply Runs**
   - After approval, the apply job runs automatically
   - Infrastructure changes are applied

## 📋 Workflow Behavior

### What Happens When You Run the Workflow?

```bash
# You trigger workflow
Actions → Deploy Infrastructure → Run workflow → dev

# Step 1: Plan (runs immediately)
✅ Checkout Code
✅ Setup Terraform
✅ Configure AWS Credentials
✅ Terraform Init
✅ Terraform Validate
✅ Terraform Plan
✅ Save Plan (as artifact)
✅ Plan Summary (shows all changes)

# Step 2: Waiting for Approval
⏸️  Job pauses with status: "Waiting"
📧 Email sent to required reviewers
👤 Engineer reviews the plan output above
✅ Engineer approves via "Review deployments" button

# Step 3: Apply (runs after approval)
✅ Checkout Code
✅ Setup Terraform
✅ Download Plan (from artifact)
✅ Terraform Apply (using saved plan)
✅ Get Outputs
✅ Deployment Summary
```

## 👥 Multi-Environment Strategy

### Development Environment
```yaml
Environment: dev
Required Reviewers: Any developer
Deployment Branch: main
Purpose: Testing and validation
```

### Staging Environment
```yaml
Environment: staging
Required Reviewers: Tech lead or senior developer
Deployment Branch: main
Purpose: Pre-production testing
```

### Production Environment
```yaml
Environment: prod
Required Reviewers: 2+ senior engineers (recommended)
Deployment Branch: main
Purpose: Production deployment
Wait Timer: 5-10 minutes (optional "cooling off" period)
```

## 🛡️ Security Benefits

### Why Manual Approval?

1. **Prevent Accidental Changes**
   - ❌ No more accidental infrastructure destruction
   - ❌ No more unintended resource modifications
   - ✅ Every change is explicitly reviewed

2. **Cost Control**
   - 👀 Review resource counts and sizes before creation
   - 💰 Catch expensive mistakes (e.g., wrong instance type)
   - 📊 Validate scaling configurations

3. **Compliance & Audit**
   - 📝 GitHub records who approved each deployment
   - ⏰ Timestamp of approval
   - 🔍 Audit trail for compliance requirements

4. **Knowledge Sharing**
   - 👥 Multiple team members can review changes
   - 🎓 Junior developers can learn by reviewing plans
   - 💬 Opportunity for discussion before applying

## 📱 Notification Setup

### Enable Email Notifications

1. **GitHub Settings → Notifications**
   ```
   https://github.com/settings/notifications
   ```

2. **Enable Workflow Notifications**
   - ☑️ **"Actions"** → **"Notify me when a workflow run requires my approval"**

3. **Configure Email Preferences**
   - Receive email immediately when approval is needed
   - Includes link to review the deployment

### Slack Integration (Optional)

```yaml
# Add to your workflow (in the plan job)
- name: Notify Slack
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🔍 Terraform Plan Ready for Review",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Environment:* ${{ github.event.inputs.environment }}\n*Status:* Plan completed, waiting for approval\n*Link:* ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## 🚨 Troubleshooting

### Issue: "Review deployments" button doesn't appear

**Cause:** Environment protection rules not configured

**Solution:**
1. Go to Settings → Environments
2. Select the environment (dev/staging/prod)
3. Add "Required reviewers"
4. Save protection rules
5. Re-run the workflow

### Issue: Workflow fails with "Environment not found"

**Cause:** Environment doesn't exist in GitHub

**Solution:**
```bash
# Create the environment via web UI:
Settings → Environments → New environment → dev
```

### Issue: Multiple people need to approve

**Cause:** Multiple reviewers required

**Solution:**
- This is by design for production environments
- All required reviewers must approve
- Or reduce the number of required reviewers in environment settings

### Issue: Can't approve my own deployment

**Cause:** You triggered the workflow and are the only reviewer

**Solution:**
- Add another team member as a reviewer
- Or create a separate "deployment" account for approvals
- GitHub best practice: Have someone else review your changes

## 📚 Best Practices

### 1. Always Review the Plan Output

```bash
# Look for:
✅ Resource additions (green +)
⚠️  Resource modifications (yellow ~)
❌ Resource deletions (red -)

# Pay special attention to:
- Database deletions or recreations
- Security group changes
- IAM role modifications
- Network configuration changes
```

### 2. Use Different Reviewers for Each Environment

```
dev:      Any team member
staging:  Tech lead
prod:     Senior engineer + Tech lead (2 approvals)
```

### 3. Document Approval Rationale

When approving, add a comment:
```
✅ Approved: Adding new ECS task definition
Changes reviewed, scaling config looks good.
Expected impact: No downtime, rolling update.
```

### 4. Set Time Limits

For production, consider adding:
```yaml
environment:
  name: prod
  # Optional: Wait 10 minutes before allowing approval
  # Gives time to cancel if needed
```

## 🎓 Training Team Members

### For Reviewers

1. **Understand Terraform Changes**
   - `+` means creating new resource
   - `~` means modifying existing resource
   - `-/+` means destroying and recreating resource
   - `-` means destroying resource

2. **Check Key Areas**
   - Database changes (potential data loss)
   - Security groups (security implications)
   - Instance types/counts (cost implications)
   - Network changes (connectivity issues)

3. **Ask Questions**
   - If unsure, reject and ask for clarification
   - Better to delay than to deploy mistakes
   - Use GitHub comments to discuss

### For Workflow Triggers

1. **Always Provide Context**
   - Why are you making this change?
   - What testing has been done?
   - What's the expected impact?

2. **Be Available**
   - Stay online during the approval window
   - Be ready to answer reviewer questions
   - Monitor the deployment after approval

## 📖 Additional Resources

- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Actions Manual Approval](https://docs.github.com/en/actions/managing-workflow-runs/reviewing-deployments)
- [Terraform Plan Documentation](https://www.terraform.io/cli/commands/plan)

---

**Questions?** Open an issue or contact the DevOps team.

**Ready to Deploy?** Go to Actions → Deploy Infrastructure → Run workflow 🚀
