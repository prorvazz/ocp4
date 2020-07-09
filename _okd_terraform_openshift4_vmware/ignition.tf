locals {
  mask        = "${var.private_netmask}"
  gw          = "${var.private_gateway}"

  ignition_url = "${var.ignition_url != "" ? "${var.ignition_url}" : "http://${var.bastion_private_ip_address}" }"
}

data "ignition_file" "bootstrap_hostname" {
  filesystem = "root"
  path       = "/etc/hostname"
  mode       = "420"

  content {
    content = "${var.name}-bootstrap.${var.name}.${lower(var.private_domain)}"
  }
}

data "ignition_file" "bootstrap_static_ip" {
  filesystem = "root"
  path       = "/etc/sysconfig/network-scripts/ifcfg-ens192"
  mode       = "420"

  content {
    content = <<EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=ens192
DEVICE=ens192
ONBOOT=yes
IPADDR=${var.bootstrap_ip_address}
PREFIX=${local.mask}
GATEWAY=${local.gw}
DOMAIN=${lower(var.name)}.${var.private_domain}
DNS1=${module.dns_server.node_private_ip}
SEARCH="${lower(var.name)}.${lower(var.private_domain)} ${lower(var.private_domain)}"
EOF
  }
}

data "ignition_file" "control_plane_hostname" {
  count = "${var.control_plane["count"]}"

  filesystem = "root"
  path       = "/etc/hostname"
  mode       = "420"

  content {
    content  = "${element(data.template_file.control_plane_hostname.*.rendered, count.index)}.${lower(var.name)}.${lower(var.private_domain)}"
  }
}

data "ignition_file" "control_plane_static_ip" {
  count = "${var.control_plane["count"]}"

  filesystem = "root"
  path       = "/etc/sysconfig/network-scripts/ifcfg-ens192"
  mode       = "420"

  content {
    content = <<EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=ens192
DEVICE=ens192
ONBOOT=yes
IPADDR=${element(var.control_plane_ip_addresses, count.index)}
PREFIX=${local.mask}
GATEWAY=${local.gw}
DOMAIN=${lower(var.name)}.${var.private_domain}
DNS1=${module.dns_server.node_private_ip}
SEARCH="${lower(var.name)}.${lower(var.private_domain)} ${lower(var.private_domain)}"
EOF
  }
}

data "ignition_file" "resolv_conf" {
  filesystem = "root"
  path       = "/etc/resolv.conf"
  mode       = "644"

  content {
    content  = <<EOF
nameserver ${module.dns_server.node_private_ip}
search ${var.name}.${var.private_domain}
EOF
  }
}


data "ignition_file" "worker_hostname" {
  count = "${var.worker["count"]}"

  filesystem = "root"
  path       = "/etc/hostname"
  mode       = "420"

  content {
    content  = "${element(data.template_file.worker_hostname.*.rendered, count.index)}.${lower(var.name)}.${lower(var.private_domain)}"
  }
}

data "ignition_file" "worker_static_ip" {
  count = "${var.worker["count"]}"

  filesystem = "root"
  path       = "/etc/sysconfig/network-scripts/ifcfg-ens192"
  mode       = "420"

  content {
    content = <<EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=ens192
DEVICE=ens192
ONBOOT=yes
IPADDR=${element(var.worker_ip_addresses, count.index)}
PREFIX=${local.mask}
GATEWAY=${local.gw}
DOMAIN=${lower(var.name)}.${var.private_domain}
DNS1=${module.dns_server.node_private_ip}
SEARCH="${lower(var.name)}.${lower(var.private_domain)} ${lower(var.private_domain)}"
EOF
  }
}

data "ignition_systemd_unit" "restart" {
  name = "restart.service"

  content = <<EOF
[Unit]
ConditionFirstBoot=yes
[Service]
Type=idle
ExecStart=/sbin/reboot
[Install]
WantedBy=multi-user.target
EOF
}

data "ignition_config" "bootstrap_ign" {
  append {
    source = "${local.ignition_url}/bootstrap.ign"
  }

  systemd = [
    "${data.ignition_systemd_unit.restart.id}",
  ]

  files = [
    "${data.ignition_file.bootstrap_hostname.id}",
    "${data.ignition_file.bootstrap_static_ip.id}",
    "${data.ignition_file.resolv_conf.id}"
  ]
}

data "ignition_config" "control_plane_ign" {
  count = "${var.control_plane["count"]}"

  append {
    source = "${local.ignition_url}/master.ign"
  }

  systemd = [
    "${data.ignition_systemd_unit.restart.id}",
  ]

  files = [
    "${data.ignition_file.control_plane_hostname.*.id[count.index]}",
    "${data.ignition_file.control_plane_static_ip.*.id[count.index]}",
    "${data.ignition_file.resolv_conf.id}"
  ]
}

data "ignition_config" "worker_ign" {
  count = "${var.worker["count"]}"

  append {
    source = "${local.ignition_url}/worker.ign"
  }

  systemd = [
    "${data.ignition_systemd_unit.restart.id}",
  ]

  files = [
    "${data.ignition_file.worker_hostname.*.id[count.index]}",
    "${data.ignition_file.worker_static_ip.*.id[count.index]}",
    "${data.ignition_file.resolv_conf.id}"
  ]
}