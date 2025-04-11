resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image
      essential = true
      portMappings = var.port_mappings
      //entryPoint = var.entry_point
      command = var.command

      mountPoints = [
        {
          sourceVolume  = "efs-volume"
          containerPath = var.mount_point
        }
      ]
    }
  ])

  volume {
    name = "efs-volume"
    efs_volume_configuration {
      file_system_id = local.efs_id
      root_directory = "/"
    }
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.task_family}_cluster"
}
