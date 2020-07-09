
module "control_plane_lb" {
    source                  = "github.com/ibm-cloud-architecture/terraform-lb-haproxy-vmware"

    dependson = [
        module.dns_server.completed_resource
    ]

    vsphere_server          = "${var.vsphere_server}"

    vsphere_datacenter_id     = "${data.vsphere_datacenter.dc.id}"
    vsphere_cluster_id        = "${data.vsphere_compute_cluster.cluster.id}"
    vsphere_resource_pool_id  = "${data.vsphere_resource_pool.pool.id}"
    datastore_id              = "${var.datastore != "" ? data.vsphere_datastore.datastore.0.id : ""}"
    datastore_cluster_id      = "${var.datastore_cluster != "" ? data.vsphere_datastore_cluster.datastore_cluster.0.id : ""}"

    folder_path               = "${local.folder}"
    instance_name             = "${var.name}-console"

    private_network_id  = "${data.vsphere_network.private_network.id}"
    private_ip_address  = "${var.control_plane_lb_private_ip_address}"
    private_netmask     = "${var.private_netmask}"
    private_gateway     = "${var.private_gateway}"
    private_domain      = "${var.name}.${var.private_domain}"

    dns_servers = list(module.dns_server.node_private_ip)

    # how to ssh into the template
    template                         = "${var.rhel_template}"
    template_ssh_user                = "${var.ssh_user}"
    template_ssh_password            = "${var.ssh_password}"
    template_ssh_private_key         = "${file(var.ssh_private_key_file)}"

    rhn_username       = "${var.rhn_username}"
    rhn_password       = "${var.rhn_password}"
    rhn_poolid         = "${var.rhn_poolid}"

    frontend = ["6443", "22623"]
    backend = {
        "6443" = "${join(",", compact(concat(var.control_plane_ip_addresses, list(var.bootstrap_complete ? "" : var.bootstrap_ip_address))))}",
        "22623" = "${join(",", compact(concat(var.control_plane_ip_addresses, list(var.bootstrap_complete ? "" : var.bootstrap_ip_address))))}"
    }
}

module "app_lb" {
    source                  = "github.com/ibm-cloud-architecture/terraform-lb-haproxy-vmware"

    dependson = [
        module.dns_server.completed_resource
    ]

    vsphere_server          = "${var.vsphere_server}"
    vsphere_datacenter_id     = "${data.vsphere_datacenter.dc.id}"
    vsphere_cluster_id        = "${data.vsphere_compute_cluster.cluster.id}"
    vsphere_resource_pool_id  = "${data.vsphere_resource_pool.pool.id}"
    datastore_id              = "${var.datastore != "" ? data.vsphere_datastore.datastore.0.id : ""}"
    datastore_cluster_id      = "${var.datastore_cluster != "" ? data.vsphere_datastore_cluster.datastore_cluster.0.id : ""}"

    folder_path               = "${local.folder}"
    instance_name             = "${var.name}-app"

    private_network_id  = "${data.vsphere_network.private_network.id}"
    private_ip_address  = "${var.app_lb_private_ip_address}"
    private_netmask     = "${var.private_netmask}"
    private_gateway     = "${var.private_gateway}"
    private_domain      = "${var.name}.${var.private_domain}"

    dns_servers = list(module.dns_server.node_private_ip)

    # how to ssh into the template
    template                         = "${var.rhel_template}"
    template_ssh_user                = "${var.ssh_user}"
    template_ssh_password            = "${var.ssh_password}"
    template_ssh_private_key         = "${file(var.ssh_private_key_file)}"

    rhn_username       = "${var.rhn_username}"
    rhn_password       = "${var.rhn_password}"
    rhn_poolid         = "${var.rhn_poolid}"

    frontend = ["80", "443"]
    backend = {
        "443" = "${join(",", var.worker_ip_addresses)}"
        "80" = "${join(",", var.worker_ip_addresses)}"
    }
}