resource "aws_iam_role" "this" {
  name = var.role_name
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = var.principal  
      }
    ]
  })
}
