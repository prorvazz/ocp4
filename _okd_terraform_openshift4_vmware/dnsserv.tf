resource "random_id" "rndc_key" {
    byte_length = 16
}

module "dns_server" {
    source                  = "git::ssh://git@github.ibm.com/jkwong/terraform-dns-bind-rhel-vmware.git"

    vsphere_server            = "${var.vsphere_server}"
    vsphere_datacenter_id     = "${data.vsphere_datacenter.dc.id}"
    vsphere_cluster_id        = "${data.vsphere_compute_cluster.cluster.id}"
    vsphere_resource_pool_id  = "${data.vsphere_resource_pool.pool.id}"
    datastore_id              = "${var.datastore != "" ? data.vsphere_datastore.datastore.0.id : ""}"
    datastore_cluster_id      = "${var.datastore_cluster != "" ? data.vsphere_datastore_cluster.datastore_cluster.0.id : ""}"

    folder_path               = "${local.folder}"
    instance_name             = "${var.name}"

    private_network_id  = "${data.vsphere_network.private_network.id}"
    private_ip_address  = "${var.dns_ip_address}"
    private_netmask     = "${var.private_netmask}"
    private_gateway     = "${var.private_gateway}"
    private_domain      = "${var.private_domain}"

    upstream_dns_servers = compact(concat(var.public_dns_servers, var.private_dns_servers))

    # how to ssh into the template
    template                         = "${var.rhel_template}"
    template_ssh_user                = "${var.ssh_user}"
    template_ssh_password            = "${var.ssh_password}"
    template_ssh_private_key         = "${file(var.ssh_private_key_file)}"

    rhn_username       = "${var.rhn_username}"
    rhn_password       = "${var.rhn_password}"
    rhn_poolid         = "${var.rhn_poolid}"

    forward_zone = "${var.name}.${var.private_domain}"

    rndc_key_name   = "${var.dns_key_name}"
    rndc_key_secret = "${var.dns_key_secret != "" ? var.dns_key_secret : random_id.rndc_key.b64_std}"
    rndc_key_algorithm = "${var.dns_key_algorithm}"

}