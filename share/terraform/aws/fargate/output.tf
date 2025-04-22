output "task_arn" {
  description = "Task arn"
  value = aws_ecs_task_definition.this.arn
}

output "cluster_arn" {
  description = "Task arn"
  value = aws_ecs_cluster.this.arn
}

