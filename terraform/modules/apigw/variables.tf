variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "api_description" {
  description = "Description of the API"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Deployment stage name (e.g. dev, prod)"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda invoke ARN for the integration"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name (for permission resource)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
