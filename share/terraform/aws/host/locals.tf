locals {

  ssh_key_list = var.ssh_key != null ? [var.ssh_key] : (var.ssh_keys == null ? [] : var.ssh_keys)

  ssh_key_txt = "- ${join("\n- ",local.ssh_key_list)} "

  cloud_config =<<EOF
#cloud-config
ssh_authorized_keys:
${local.ssh_key_txt}
EOF

  user_data     = var.user_data != null ?  var.user_data : base64encode(local.cloud_config)
}

