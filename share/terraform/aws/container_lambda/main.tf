resource "aws_efs_access_point" "lambda_ap" {
  file_system_id = local.efs_id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = var.mount_point
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  package_type  = "Image"

  image_uri = var.image

  role = var.role_arn

  timeout     = var.timeout
  memory_size = var.memory

  environment {
    variables = var.environment_variables
  }

  vpc_config {
    subnet_ids         = data.aws_subnets.default_vpc_subnets.ids
    security_group_ids = local.security_group_ids
  }

  file_system_config {
    arn              = aws_efs_access_point.lambda_ap.arn
    local_mount_path = "/mnt/efs"
  }

  image_config {
    command = ["app.handler"]
  }
}
