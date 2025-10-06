# General Configuration
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "devops-showcase"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for auto-scaling"
  type        = number
  default     = 4
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "container_image" {
  description = "Docker image for the application (will be set to ECR repo)"
  type        = string
  default     = "" # Will be populated from ECR output
}

# EC2 Configuration for ECS
variable "ecs_instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.small"
}

variable "ecs_cluster_size" {
  description = "Number of EC2 instances in ECS cluster"
  type        = number
  default     = 2
}

variable "ecs_cluster_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 4
}

# RDS Configuration
variable "db_engine_version" {
  description = "PostgreSQL engine version (major version, AWS will use latest minor version)"
  type        = string
  default     = "17"
  # PostgreSQL 17 is the latest major version available on AWS RDS (currently 17.6)
  # Includes improved performance, better JSON support, and enhanced vacuum
  # AWS automatically uses the latest minor version
  # To use a different version: 16 (stable, 16.10) or 15 (conservative, 15.14)
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "devops_showcase"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

# Note: Database password is auto-generated using random_password resource
# and stored securely in AWS Systems Manager Parameter Store

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

# ALB Configuration
variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

# Auto-scaling Configuration
variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}

# EC2 Configuration
variable "key_name" {
  description = "EC2 SSH key pair name (optional - SSM Session Manager is enabled)"
  type        = string
  default     = ""
}

# Basic Authentication Configuration
variable "basic_auth_user" {
  description = "Basic authentication username"
  type        = string
  default     = "admin"
}

# Note: basic_auth_password is stored in AWS Parameter Store
# and will be set manually for security reasons

# GitHub OIDC Configuration
variable "github_repo_name" {
  description = "GitHub repository name in format 'organization/repository'"
  type        = string
  default     = "YOUR-GITHUB-USERNAME/devops_showcase"
  # Example: "kdvalkov/ecs-distributed-platform-showcase"
  # The module will automatically configure OIDC trust for this repository
  # By default, all branches can deploy. To restrict to main branch only,
  # modify the module configuration in github-oidc.tf
}
