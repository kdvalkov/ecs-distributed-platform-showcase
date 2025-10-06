# Random Password Generation and Secure Storage
# This file manages the RDS database password securely

# Generate a random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the password in AWS Systems Manager Parameter Store (SecureString)
resource "aws_ssm_parameter" "db_password" {
  name        = "/${local.name_prefix}/database/master-password"
  description = "Master password for RDS database"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-db-password"
    }
  )
}

# Store database connection details for easy reference
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${local.name_prefix}/database/endpoint"
  description = "RDS database endpoint"
  type        = "String"
  value       = module.rds.db_instance_endpoint

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-db-endpoint"
    }
  )
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/${local.name_prefix}/database/name"
  description = "RDS database name"
  type        = "String"
  value       = var.db_name

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-db-name"
    }
  )
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${local.name_prefix}/database/username"
  description = "RDS database username"
  type        = "String"
  value       = var.db_username

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-db-username"
    }
  )
}
