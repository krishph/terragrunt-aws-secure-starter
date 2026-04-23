variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Lambda handler (file.function)"
  type        = string
  default     = "index.handler"
}

variable "filename" {
  description = "Path to the deployment zip file"
  type        = string
}

variable "source_hash" {
  description = "Base64-encoded SHA256 of the source code (use filebase64sha256 of the source file, not the zip)"
  type        = string
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket Lambda can access"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket (injected as env var)"
  type        = string
}

variable "environment_variables" {
  description = "Additional environment variables for Lambda"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
