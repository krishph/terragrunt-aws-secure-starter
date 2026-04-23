include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/lambda"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id                   = "vpc-mock"
    private_subnet_ids       = ["subnet-mock1", "subnet-mock2"]
    lambda_security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["destroy", "validate"]
}

dependency "s3" {
  config_path = "../s3"
  mock_outputs = {
    bucket_arn  = "arn:aws:s3:::mock-bucket"
    bucket_name = "mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["destroy", "validate"]
}

inputs = {
  function_name            = "devto-dev-handler"
  runtime                  = "python3.12"
  handler                  = "index.handler"
  filename                 = "${get_repo_root()}/lambda/handler.zip"
  source_hash              = filebase64sha256("${get_repo_root()}/lambda/index.py")
  timeout                  = 30
  memory_size              = 128
  private_subnet_ids       = dependency.vpc.outputs.private_subnet_ids
  lambda_security_group_id = dependency.vpc.outputs.lambda_security_group_id
  s3_bucket_arn            = dependency.s3.outputs.bucket_arn
  s3_bucket_name           = dependency.s3.outputs.bucket_name
  log_retention_days       = 7
  environment_variables    = {}
}
