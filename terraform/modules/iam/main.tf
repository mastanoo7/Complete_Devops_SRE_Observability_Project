# ============================================================
# Terraform IAM Module — IRSA roles for microservices
# Creates per-service IAM roles with OIDC trust policies
# ============================================================

locals {
  name_prefix  = "${var.project}-${var.environment}"
  oidc_subject = replace(var.oidc_provider_url, "https://", "")

  common_tags = merge(var.tags, {
    Module      = "iam"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── Helper: IRSA Trust Policy ────────────────────────────────
data "aws_iam_policy_document" "irsa_trust" {
  for_each = var.service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_subject}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_subject}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IRSA Roles per Service ───────────────────────────────────
resource "aws_iam_role" "service" {
  for_each = var.service_accounts

  name               = "${local.name_prefix}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust[each.key].json

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-role"
    Service = each.key
  })
}

# ── Auth Service Policy ──────────────────────────────────────
resource "aws_iam_policy" "auth_service" {
  name        = "${local.name_prefix}-auth-service-policy"
  description = "Policy for auth-service: Secrets Manager access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${local.name_prefix}/auth-service/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "auth_service" {
  count      = contains(keys(var.service_accounts), "auth-service") ? 1 : 0
  policy_arn = aws_iam_policy.auth_service.arn
  role       = aws_iam_role.service["auth-service"].name
}

# ── Product Service Policy ───────────────────────────────────
resource "aws_iam_policy" "product_service" {
  name        = "${local.name_prefix}-product-service-policy"
  description = "Policy for product-service: S3 + Secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.assets_bucket_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.assets_bucket_name}"
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${local.name_prefix}/product-service/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "product_service" {
  count      = contains(keys(var.service_accounts), "product-service") ? 1 : 0
  policy_arn = aws_iam_policy.product_service.arn
  role       = aws_iam_role.service["product-service"].name
}

# ── Order Service Policy ─────────────────────────────────────
resource "aws_iam_policy" "order_service" {
  name        = "${local.name_prefix}-order-service-policy"
  description = "Policy for order-service: SQS + SNS + Secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:*:*:${local.name_prefix}-orders-*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:*:*:${local.name_prefix}-*"
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${local.name_prefix}/order-service/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "order_service" {
  count      = contains(keys(var.service_accounts), "order-service") ? 1 : 0
  policy_arn = aws_iam_policy.order_service.arn
  role       = aws_iam_role.service["order-service"].name
}

# ── Notification Service Policy ──────────────────────────────
resource "aws_iam_policy" "notification_service" {
  name        = "${local.name_prefix}-notification-service-policy"
  description = "Policy for notification-service: SES + SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "noreply@nexacommerce.com"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:*:*:${local.name_prefix}-notifications-*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "notification_service" {
  count      = contains(keys(var.service_accounts), "notification-service") ? 1 : 0
  policy_arn = aws_iam_policy.notification_service.arn
  role       = aws_iam_role.service["notification-service"].name
}
