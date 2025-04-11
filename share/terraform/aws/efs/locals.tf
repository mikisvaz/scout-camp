locals {
  security_group_ids = [
    for sg_key in var.sg_keys :
    lookup(var.remote.outputs, sg_key, null)
  ]
}
