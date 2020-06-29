data "aws_iam_policy_document" "lambda_function" {
  statement {
    actions = [
    "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
      "lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "lambda_backup_role" {
  name               = "lambda-backup-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_function.json
  tags = {
    Name = "lambda-backup-role"
  }
}

resource "aws_iam_policy" "lambda_backup_policy" {
  name        = "lambda-backup-policy"
  path        = "/"
  description = "IAM Policy for lambda-backup function"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeTags",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeImages",
                "ec2:DescribeSnapshotAttribute",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateImage",
                "ec2:CreateSnapshot",
                "ec2:CreateSnapshots",
                "ec2:DeleteSnapshot",
                "ec2:DeregisterImage"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_backup_attachments" {
  role       = aws_iam_role.lambda_backup_role.name
  policy_arn = aws_iam_policy.lambda_backup_policy.arn
}