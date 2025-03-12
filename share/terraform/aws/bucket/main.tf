provider "aws" {
  region = "eu-west-2"  # Change to your preferred AWS region
}

resource "aws_s3_bucket" "this" {
  bucket = var.name  # Change to a globally unique name
}

