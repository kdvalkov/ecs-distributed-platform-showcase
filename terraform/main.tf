# Local variables
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

################################################################################
# VPC Module - Using community module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets   = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k + length(var.availability_zones))]
  database_subnets = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k + 2 * length(var.availability_zones))]

  create_database_subnet_group = true

  enable_nat_gateway   = true
  single_nat_gateway   = true # Single-AZ NAT for lower costs
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

################################################################################
# ECR Repository
################################################################################

resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

################################################################################
# Security Groups
################################################################################

# ALB Security Group
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS from internet"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  ]

  tags = local.tags
}

# ECS Security Group
module "ecs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "Allow traffic from ALB"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  ]

  tags = local.tags
}

# RDS Security Group
module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.ecs_sg.security_group_id
      description              = "PostgreSQL from ECS tasks"
    }
  ]

  tags = local.tags
}

################################################################################
# Application Load Balancer
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "${local.name_prefix}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Security group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.showcase.arn

      forward = {
        target_group_key = "ecs_app"
      }
    }
  }

  target_groups = {
    ecs_app = {
      name_prefix = "ecs-"
      protocol    = "HTTP"
      port        = var.container_port
      target_type = "ip"

      health_check = {
        enabled             = true
        path                = var.health_check_path
        interval            = var.health_check_interval
        timeout             = var.health_check_timeout
        healthy_threshold   = var.health_check_healthy_threshold
        unhealthy_threshold = var.health_check_unhealthy_threshold
        matcher             = "200"
      }

      deregistration_delay = 30

      create_attachment = false
    }
  }

  tags = local.tags
}

################################################################################
# RDS PostgreSQL Database
################################################################################

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name_prefix}-db"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2

  # Explicitly set parameter group creation options
  create_db_parameter_group       = true
  parameter_group_name            = null # Let the module generate the name automatically
  parameter_group_use_name_prefix = true

  # Disable SSL requirement for dev environment
  parameters = [
    {
      name  = "rds.force_ssl"
      value = "0"
    }
  ]

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # Use our own password management instead of AWS Secrets Manager
  manage_master_user_password = false

  multi_az               = var.db_multi_az
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  tags = local.tags
}

################################################################################
# ECS Cluster Module
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 6.6"

  name = "${local.name_prefix}-cluster"

  # Cluster settings
  setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  # Autoscaling capacity providers
  autoscaling_capacity_providers = {
    main = {
      auto_scaling_group_arn = module.autoscaling.autoscaling_group_arn

      managed_scaling = {
        maximum_scaling_step_size = 2
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 80
      }

      managed_termination_protection = "ENABLED"
      managed_draining               = "ENABLED"
    }
  }

  tags = local.tags
}

################################################################################
# Auto Scaling Group for ECS Instances
################################################################################

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  name = "${local.name_prefix}-ecs-asg"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = var.ecs_instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  security_groups = [module.ecs_sg.security_group_id]
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name            = module.ecs_cluster.name
    container_instance_tags = jsonencode(local.tags)
  }))
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = "${local.name_prefix}-ecs-instance"
  iam_role_description        = "ECS instance role for ${local.name_prefix}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = var.ecs_cluster_size
  max_size            = var.ecs_cluster_max_size
  desired_capacity    = var.ecs_cluster_size

  # Required for managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  # ECS managed tag for capacity provider
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 30
        volume_type           = "gp3"
        delete_on_termination = true
        encrypted             = true
      }
    }
  ]

  tags = local.tags
}

################################################################################
# ECS Service Module
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 6.6"

  name        = "${local.name_prefix}-service"
  cluster_arn = module.ecs_cluster.arn

  # Task Definition
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  # Use existing IAM roles
  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = aws_iam_role.ecs_task_execution.arn
  create_tasks_iam_role     = false
  tasks_iam_role_arn        = aws_iam_role.ecs_task.arn

  # Capacity provider strategy
  capacity_provider_strategy = {
    main = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["main"].name
      weight            = 1
      base              = 1
    }
  }

  # Container definitions
  container_definitions = {
    app = {
      name                     = "app"
      image                    = "${aws_ecr_repository.app.repository_url}:latest"
      essential                = true
      readonly_root_filesystem = false

      portMappings = [
        {
          name          = "app"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DB_HOST"
          value = split(":", module.rds.db_instance_endpoint)[0]
        },
        {
          name  = "DB_PORT"
          value = "5432"
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      # Secrets from AWS Systems Manager Parameter Store
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_ssm_parameter.db_password.arn
        }
      ]

      health_check = {
        command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:${var.container_port}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # CloudWatch logs
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${local.name_prefix}-app"
      cloudwatch_log_group_retention_in_days = 7

      log_configuration = {
        logDriver = "awslogs"
      }
    }
  }

  # Load balancer
  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["ecs_app"].arn
      container_name   = "app"
      container_port   = var.container_port
    }
  }

  # Network configuration
  subnet_ids = module.vpc.private_subnets

  # Use existing security group instead of creating a new one
  create_security_group = false
  security_group_ids    = [module.ecs_sg.security_group_id]

  # Service settings
  desired_count                     = var.ecs_desired_count
  health_check_grace_period_seconds = 60
  enable_execute_command            = true

  # Deployment circuit breaker
  deployment_circuit_breaker = {
    enable   = true
    rollback = false
  }

  # Autoscaling
  enable_autoscaling       = true
  autoscaling_min_capacity = var.ecs_min_capacity
  autoscaling_max_capacity = var.ecs_max_capacity

  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = var.cpu_target_value
        scale_in_cooldown  = 300
        scale_out_cooldown = 60
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value       = var.memory_target_value
        scale_in_cooldown  = 300
        scale_out_cooldown = 60
      }
    }
  }

  depends_on = [
    module.alb,
    aws_iam_role.ecs_task_execution
  ]

  tags = local.tags
}

################################################################################
# Data Sources
################################################################################

# Get the latest ECS-optimized AMI
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}
