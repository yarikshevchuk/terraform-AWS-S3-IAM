terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Name = "Main provider"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  region = var.aws_backup_region

  default_tags {
    tags = {
      Name = "Backup provider"
      ManagedBy = "Terraform"
    }
  }
}