resource "aws_lambda_function" "this" {
  function_name = var.function_name
  handler       = "lambda_function.lambda_handler"
  runtime       = var.runtime
  filename      = var.filename
  source_code_hash = filebase64sha256(var.filename)
  timeout       = var.timeout
  role          = var.role

  environment {
    variables = var.environment_variables
  }
}
