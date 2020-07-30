data "archive_file" "lambda_backup_function_zip" {
  type        = "zip"
  source_dir  = format("%s/lambda/", path.root)
  output_path = format("%s/lambda.zip", path.root)
}

resource "aws_lambda_function" "lambda_backup_function" {
  filename         = "lambda.zip"
  function_name    = "lambda_images_backup"
  role             = aws_iam_role.lambda_backup_role.arn
  handler          = "main.images_handler"
  depends_on       = [aws_cloudwatch_log_group.lambda_backup_log_group]
  source_code_hash = data.archive_file.lambda_backup_function_zip.output_base64sha256
  description      = "Making backups for instances via snapshots"
  runtime          = "python3.8"
  timeout          = 600
}

resource "aws_cloudwatch_log_group" "lambda_backup_log_group" {
  name              = format("/aws/lambda/%s", "lambda_images_backup")
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "lambda_backup" {
  count               = length(keys(var.plan))
  name                = format("backup-%s-rule", keys(var.plan)[count.index])
  description         = format("Invoke lambda function for %s", keys(var.plan)[count.index])
  schedule_expression = var.plan[keys(var.plan)[count.index]]
}

resource "aws_cloudwatch_event_target" "lambda_backup" {
  depends_on = [aws_cloudwatch_event_rule.lambda_backup]
  count      = length(keys(var.plan))
  rule       = aws_cloudwatch_event_rule.lambda_backup[count.index].name
  target_id  = format("lambda_backup_function-%s", keys(var.plan)[count.index])
  arn        = aws_lambda_function.lambda_backup_function.arn
  input      = jsonencode({ plan_name = keys(var.plan)[count.index] })
}

resource "aws_lambda_permission" "lambda_backup" {
  count         = length(keys(var.plan))
  statement_id  = format("AllowExecutionFromCloudWatch%s", keys(var.plan)[count.index])
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_backup_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_backup[count.index].arn
}
