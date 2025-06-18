locals {
  workspace_suffix = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
  environment      = terraform.workspace == "default" ? "default" : terraform.workspace
}

data "archive_file" "lambda_backup_function_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/"
  output_path = "${path.root}/lambda.zip"
  excludes    = ["__pycache__", "*.pyc", ".DS_Store"]
}

resource "aws_lambda_function" "lambda_backup_function" {
  filename         = "lambda.zip"
  function_name    = "${var.lambda_function_name}${local.workspace_suffix}"
  role            = aws_iam_role.lambda_backup_role.arn
  handler         = "main.images_handler"
  depends_on      = [aws_cloudwatch_log_group.lambda_backup_log_group]
  source_code_hash = data.archive_file.lambda_backup_function_zip.output_base64sha256
  description     = "Making backups for instances via snapshots - ${local.environment}"
  runtime         = "python3.11"
  timeout         = 600
  
  architectures = ["x86_64"]
  
  environment {
    variables = {
      ENVIRONMENT = local.environment
      WORKSPACE   = terraform.workspace
    }
  }

  tags = {
    Name        = "${var.lambda_function_name}${local.workspace_suffix}"
    Environment = local.environment
    Workspace   = terraform.workspace
  }
}

resource "aws_cloudwatch_log_group" "lambda_backup_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}${local.workspace_suffix}"
  retention_in_days = 30

  tags = {
    Name        = "lambda-backup-log-group${local.workspace_suffix}"
    Environment = local.environment
    Workspace   = terraform.workspace
  }
}

resource "aws_cloudwatch_event_rule" "lambda_backup" {
  count               = length(keys(var.plan))
  name                = "backup-${keys(var.plan)[count.index]}-rule${local.workspace_suffix}"
  description         = "Invoke lambda function for ${keys(var.plan)[count.index]} in ${local.environment}"
  schedule_expression = var.plan[keys(var.plan)[count.index]]
  state              = "ENABLED"

  tags = {
    Name        = "backup-${keys(var.plan)[count.index]}-rule${local.workspace_suffix}"
    Environment = local.environment
    Workspace   = terraform.workspace
  }
}

resource "aws_cloudwatch_event_target" "lambda_backup" {
  count      = length(keys(var.plan))
  depends_on = [aws_cloudwatch_event_rule.lambda_backup]
  rule       = aws_cloudwatch_event_rule.lambda_backup[count.index].name
  target_id  = "lambda_backup_function-${keys(var.plan)[count.index]}${local.workspace_suffix}"
  arn        = aws_lambda_function.lambda_backup_function.arn
  
  input = jsonencode({
    plan_name = keys(var.plan)[count.index]
  })
}

resource "aws_lambda_permission" "lambda_backup" {
  count         = length(keys(var.plan))
  statement_id  = "AllowExecutionFromCloudWatch${keys(var.plan)[count.index]}${replace(local.workspace_suffix, "-", "")}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_backup_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_backup[count.index].arn
}
