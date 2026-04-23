locals {
  aws_region             = "us-east-1"
  account_id             = "<AWS-ACCOUNT#>"                # ⚠️  replace with your 12-digit AWS account ID
  terraform_state_bucket = "terraform-state-bucket"        # ⚠️  must match bootstrap/terraform.tfvars
  terraform_lock_table   = "terraform-state-lock"          # ⚠️  must match bootstrap/terraform.tfvars
}
