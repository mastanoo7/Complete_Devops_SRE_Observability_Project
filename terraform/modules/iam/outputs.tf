# ============================================================
# Terraform IAM Module — Outputs
# ============================================================

output "service_role_arns" {
  description = "Map of service name to IAM role ARN"
  value = {
    for name, role in aws_iam_role.service :
    name => role.arn
  }
}

output "service_role_names" {
  description = "Map of service name to IAM role name"
  value = {
    for name, role in aws_iam_role.service :
    name => role.name
  }
}
