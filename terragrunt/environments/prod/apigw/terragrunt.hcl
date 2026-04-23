include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/apigw"
}

dependency "lambda" {
  config_path = "../lambda"
  mock_outputs = {
    invoke_arn    = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/mock/invocations"
    function_name = "mock-function"
  }
  mock_outputs_allowed_terraform_commands = ["destroy", "validate"]
}

inputs = {
  api_name             = "devto-prod-api"
  api_description      = "devto prod REST API"
  stage_name           = "prod"
  lambda_invoke_arn    = dependency.lambda.outputs.invoke_arn
  lambda_function_name = dependency.lambda.outputs.function_name
}
