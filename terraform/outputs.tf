# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.dns_name}"
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs_service.task_definition_arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "Name of the database"
  value       = module.rds.db_instance_name
}

output "rds_port" {
  description = "Port of the RDS instance"
  value       = module.rds.db_instance_port
}

output "rds_address" {
  description = "Address of the RDS instance"
  value       = module.rds.db_instance_address
  sensitive   = true
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_sg.security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_sg.security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.rds_sg.security_group_id
}

# GitHub OIDC Outputs
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = module.github_oidc.oidc_role
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.github_oidc.oidc_provider_arn
}

# Secrets Management Outputs
output "db_password_parameter_name" {
  description = "Name of the SSM parameter storing the database password"
  value       = aws_ssm_parameter.db_password.name
}

output "db_password_parameter_arn" {
  description = "ARN of the SSM parameter storing the database password"
  value       = aws_ssm_parameter.db_password.arn
  sensitive   = true
}

# DNS & Certificate Outputs
output "route53_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.showcase.arn
}

output "domain_name" {
  description = "Domain name for the application"
  value       = "showcase.valkov.cloud"
}

output "application_https_url" {
  description = "HTTPS URL to access the application"
  value       = "https://showcase.valkov.cloud"
}

# Summary Output
output "deployment_summary" {
  description = "Summary of the deployment"
  value       = <<-EOT
    
    ╔════════════════════════════════════════════════════════════╗
    ║         DevOps Showcase - Deployment Summary              ║
    ╚════════════════════════════════════════════════════════════╝
    
    🌐 Application URL:    https://showcase.valkov.cloud
    🔗 ALB DNS:            http://${module.alb.dns_name}
    📦 ECR Repository:     ${aws_ecr_repository.app.repository_url}
    🐳 ECS Cluster:        ${module.ecs_cluster.name}
    📊 ECS Service:        ${module.ecs_service.name}
    🗄️  RDS Endpoint:       ${split(":", module.rds.db_instance_endpoint)[0]}
    🔒 Database Name:      ${module.rds.db_instance_name}
    🔐 GitHub Actions Role: ${module.github_oidc.oidc_role}
    🔑 DB Password (SSM):  ${aws_ssm_parameter.db_password.name}
    
    ⚠️  Important: Database password is auto-generated and stored securely in AWS Parameter Store
    
    DNS Configuration:
    Ensure Route53 hosted zone 'valkov.cloud' is created manually in AWS
    and nameservers are configured in Namecheap
    
    GitHub Actions Setup:
    1. Add GitHub secret AWS_ROLE_ARN with value above
    2. Push to main branch to trigger deployment
    
    Next Steps:
    1. Ensure Route53 hosted zone 'valkov.cloud' exists in AWS
    2. Update Namecheap nameservers to point to Route53 (if not done)
    3. Wait for DNS propagation (~5-60 minutes)
    4. Configure GitHub repository secrets (see docs)
    5. Build and push Docker image to ECR (or let GitHub Actions do it)
    6. Update ECS service to use the new image
    7. Access application at https://showcase.valkov.cloud
    8. Test fail-over scenarios
    
  EOT
}
