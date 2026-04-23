variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "github-actions-deploy-role"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}
