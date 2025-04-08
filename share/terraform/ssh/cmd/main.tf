terraform {
  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = ">= 1.0.0"
    }
  }
}

resource "ssh_resource" "up" {
  host = var.host
  user = var.user
  agent = true
  when = "create"

  commands = [
    "${var.command} > ${var.service_id}.log 2>&1 & echo $! > /tmp/${var.service_id}.pid"
  ]

}

resource "ssh_resource" "down" {
  host = var.host
  user = var.user
  agent = true
  when = "destroy"

  commands = [
    "kill $(cat /tmp/${var.service_id}.pid) || true",
    "rm -f /tmp/${var.service_id}.pid"
  ]
}


