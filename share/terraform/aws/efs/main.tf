resource "aws_efs_file_system" "this" {
  creation_token = "herlab-efs"
  tags = {
    Name = "HERLab main EFS"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(data.aws_subnets.all.ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = local.security_group_ids
}
