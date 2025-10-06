terraform {
  required_version = ">= 1.12.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # S3 Backend for state management with native locking
  # Run scripts/bootstrap-backend.sh first to create the S3 bucket
  # Then uncomment this block and run: terraform init -reconfigure
  #
  # backend "s3" {
  #   bucket  = "devops-showcase-dev-tfstate-<YOUR-ACCOUNT-ID>"
  #   key     = "terraform.tfstate"
  #   region  = "eu-central-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DevOps-Showcase"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
