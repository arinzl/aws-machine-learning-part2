
resource "aws_iam_role" "notebook" {
  name               = "${var.app_name}-notebook"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_policy.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

}

data "aws_iam_policy_document" "sagemaker_assume_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role_policy" "notebook" {
  name   = aws_iam_role.notebook.name
  role   = aws_iam_role.notebook.id
  policy = data.aws_iam_policy_document.notebook.json
}


data "aws_iam_policy_document" "notebook" {

  statement {
    sid    = "mlencryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = [
      aws_kms_key.kms_key.arn,
    ]
  }

}
