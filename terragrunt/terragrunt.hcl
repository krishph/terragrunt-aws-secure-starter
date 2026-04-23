locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  aws_region             = local.account_vars.locals.aws_region
  account_id             = local.account_vars.locals.account_id
  terraform_state_bucket = local.account_vars.locals.terraform_state_bucket
  terraform_lock_table   = local.account_vars.locals.terraform_lock_table
  environment            = local.env_vars.locals.environment
  project                = "devto"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = {
      Project     = "${local.project}"
      Environment = "${local.environment}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = local.terraform_state_bucket
    key            = "${local.environment}/${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = local.terraform_lock_table
  }
}

inputs = {
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}
