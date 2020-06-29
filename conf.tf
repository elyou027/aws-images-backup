provider "aws" {
  profile = var.aws_profile
  version = "~> 2"
  region = var.aws_region
}

provider "archive" {
  version = "~> 1.3"
}
