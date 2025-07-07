resource "aws_kms_key" "kms_key" {
  description             = "KMS for ML demo"
  policy                  = data.aws_iam_policy_document.kms_policy.json
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${var.app_name}"
  target_key_id = aws_kms_key.kms_key.id
}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "AccountUsage"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowUseForSagemaker"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.name}.amazonaws.com",
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
      ]
    }
  }

}
