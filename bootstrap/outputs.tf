output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions — add this to your repo secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  value = aws_dynamodb_table.terraform_lock.name
}
