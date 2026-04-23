terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role trusted by GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# These permissions are intentionally broad for a demo/starter repo.
# In a production setup, scope each action down to specific resource ARNs and
# split into separate policies per service. Use IAM Access Analyzer to generate
# a least-privilege policy from actual usage after your first successful deploy.
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      {
        Sid    = "DynamoDBStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.terraform_lock_table}"
      },
      {
        Sid    = "VPC"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*", "ec2:*Subnet*", "ec2:*InternetGateway*",
          "ec2:*RouteTable*", "ec2:*SecurityGroup*", "ec2:*NatGateway*",
          "ec2:*Address*", "ec2:*VpcEndpoint*", "ec2:*FlowLog*",
          "ec2:DescribeAvailabilityZones", "ec2:DescribePrefixLists",
          "ec2:DescribeTags", "ec2:DescribeNetworkAcls",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:CreateTags", "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "APIGateway"
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3App"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMLambdaRole"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:PassRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
          "iam:TagRole", "iam:UntagRole",
          "iam:CreateServiceLinkedRole",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
          "logs:TagLogGroup", "logs:ListTagsForResource",
          "logs:ListTagsLogGroup", "logs:UntagLogGroup",
          "logs:PutLogEvents", "logs:CreateLogDelivery",
          "logs:PutResourcePolicy", "logs:DescribeResourcePolicies"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 bucket for Terraform remote state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.terraform_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
