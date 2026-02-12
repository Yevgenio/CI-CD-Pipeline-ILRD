
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NO backend block - uses local state
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "Terraform-Bootstrap"
      ManagedBy = "Terraform"
      Purpose   = "Remote-State-Backend"
    }
  }
}

# Creates S3 bucket and DynamoDB table for remote state backend
resource "aws_s3_bucket" "terraform_state" {
  bucket = "yevgeni-terraform-state"

  tags = {
    Name        = "Terraform State Storage"
    Description = "Stores Terraform state files for all projects"
  }
}

# Enable Versioning 
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Locks"
    Description = "Prevents concurrent Terraform runs"
  }
}