locals {
  security_group_ids = [
    for sg_key in var.sg_keys :
    lookup(var.network.outputs, sg_key, null)
  ]

  efs_id = lookup(var.efs.outputs, "aws_efs_id", null)
}
