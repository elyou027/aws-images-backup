variable "plan" {
  default = {
    BackupDaily   = "cron(10 10 * * ? *)"
    BackupWeekly  = "cron(30 10 ? * 1 *)"
    BackupMonthly = "cron(50 10 1 * ? *)"
  }
}

variable "lambda_function_name" {
  default = "lambda_images_backup"
}

variable aws_profile {}

variable "aws_region" {}
