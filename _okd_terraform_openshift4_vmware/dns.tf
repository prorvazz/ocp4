data "template_file" "etcd_hostname" {
    count = "${var.control_plane["count"]}"

    template = "${format("etcd-%d.%s", count.index, lower(var.name))}"
}

data "template_file" "control_plane_hostname" {
    count = "${var.control_plane["count"]}"

    template = "${format("%s-master%02d", lower(var.name), count.index + 1)}"
}

data "template_file" "control_plane_hostname_a" {
    count = "${var.control_plane["count"]}"

    template = "${format("%s.%s", element(data.template_file.control_plane_hostname.*.rendered, count.index), lower(var.name))}"
}

data "template_file" "worker_hostname" {
    count = "${var.worker["count"]}"

    template = "${format("%s-worker%02d", lower(var.name), count.index + 1)}"
}

data "template_file" "worker_hostname_a" {
    count = "${var.worker["count"]}"

    template = "${format("%s.%s", element(data.template_file.worker_hostname.*.rendered, count.index), lower(var.name))}"
}


data "template_file" "etcd_srv_hostname" {
    count = "${var.control_plane["count"]}"

    template = "${format("etcd-%d.%s.%s:2380", count.index, lower(var.name), lower(var.private_domain))}"
}

data "template_file" "etcd_srv_target" {
    count = "${var.control_plane["count"]}"

    template = "_etcd-server-ssl._tcp.${lower(var.name)}"
}


module "dns" {
    source                  = "github.com/ibm-cloud-architecture/terraform-dns-rfc2136"

    dependson = [
        module.dns_server.completed_resource
    ]

    node_count = (var.bootstrap_complete ? 0 : 1) + var.control_plane["count"] + var.worker["count"]
    create_node_ptr_records = true

    node_ips = compact(concat(
        list(var.bootstrap_complete ? "" : var.bootstrap_ip_address),
        var.control_plane_ip_addresses,
        var.worker_ip_addresses,
    ))

    node_hostnames = compact(concat(
        list(var.bootstrap_complete ? "" : "${lower(var.name)}-bootstrap.${lower(var.name)}.${var.private_domain}"),
        formatlist("%v.%v", data.template_file.control_plane_hostname_a.*.rendered, var.private_domain),
        formatlist("%v.%v", data.template_file.worker_hostname_a.*.rendered, var.private_domain),
    ))

    a_record_count = 3 + var.control_plane["count"]
    a_records = zipmap(
      concat(
        list("api.${lower(var.name)}.${var.private_domain}"),
        list("api-int.${lower(var.name)}.${var.private_domain}"),
        list("*.apps.${lower(var.name)}.${var.private_domain}"),
        formatlist("%v.%v", data.template_file.etcd_hostname.*.rendered, var.private_domain)
      ),
      concat(
        list(module.control_plane_lb.node_private_ip),
        list(module.control_plane_lb.node_private_ip),
        list(module.app_lb.node_private_ip),
        var.control_plane_ip_addresses)
    )

    srv_record_count = 1
    srv_records = list("_etcd-server-ssl._tcp.${lower(var.name)}.${var.private_domain}")
    srv_record_targets = zipmap(
        data.template_file.etcd_srv_hostname.*.rendered, 
        formatlist("%v.%v", data.template_file.etcd_srv_target.*.rendered, var.private_domain))
    
    zone_name               = "${lower(var.name)}.${var.private_domain}."
    dns_server              = module.dns_server.node_private_ip

    key_name = "${var.dns_key_name}."
    key_algorithm = var.dns_key_algorithm
    key_secret = var.dns_key_secret != "" ? var.dns_key_secret : random_id.rndc_key.b64_std

    record_ttl = var.dns_record_ttl
}