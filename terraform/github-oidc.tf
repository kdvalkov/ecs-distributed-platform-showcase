# Terraform configuration for GitHub OIDC provider
# This allows GitHub Actions to authenticate to AWS without long-lived credentials

################################################################################
# IAM Policy for GitHub Actions Deployment
################################################################################

data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR permissions
  statement {
    sid = "ECRPushPull"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = ["*"]
  }

  # ECS permissions
  statement {
    sid = "ECSDeployment"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]
    resources = ["*"]
  }

  # IAM permissions (for passing role to ECS)
  statement {
    sid = "IAMPassRole"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn
    ]
  }

  # CloudWatch Logs (for deployment logs)
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "${local.name_prefix}-github-actions-policy"
  description = "Policy for GitHub Actions to deploy to ECS"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = local.tags
}

################################################################################
# GitHub OIDC Provider & Role (using community module)
################################################################################

module "github_oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2.2"

  create_oidc_provider = true
  create_oidc_role     = true

  role_name        = "${local.name_prefix}-github-actions-role"
  role_description = "Role for GitHub Actions to deploy to AWS"

  repositories = [var.github_repo_name]

  # Attach the custom deployment policy
  oidc_role_attach_policies = [aws_iam_policy.github_actions.arn]

  tags = local.tags
}
