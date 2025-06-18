provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-lambda-ami-backups"
      ManagedBy = "terraform"
    }
  }
}

provider "archive" {
  # No configuration needed
}
