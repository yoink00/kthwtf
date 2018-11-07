provider "null" {}

# Provision the Kube Controllers
resource "null_resource" "kube_control_provision" {

  connection {
    host = "${packet_device.kube_control.*.access_public_ipv4[count.index]}"
  }

  triggers {
    host_id = "${packet_device.kube_control.*.id[count.index]}"
    cert_ids = "${tls_self_signed_cert.root.id},${tls_locally_signed_cert.kubernetes-api.id},${tls_locally_signed_cert.service-accounts.id}"
    key_ids = "${tls_private_key.root.id},${tls_private_key.kubernetes-api.id},${tls_private_key.service-accounts.id}"
  }

  provisioner "remote-exec" {
    inline = [ "mkdir -p /etc/kube-certs" ]
  }

  provisioner "file" {
    content = "${tls_self_signed_cert.root.cert_pem}"
    destination = "/etc/kube-certs/ca.pem"
  }

  provisioner "file" {
    content = "${tls_private_key.root.private_key_pem}"
    destination = "/etc/kube-certs/ca-key.pem"
  }

  provisioner "file" {
    content = "${tls_locally_signed_cert.kubernetes-api.cert_pem}"
    destination = "/etc/kube-certs/kubernetes.pem"
  }

  provisioner "file" {
    content = "${tls_private_key.kubernetes-api.private_key_pem}"
    destination = "/etc/kube-certs/kubernetes-key.pem"
  }

  provisioner "file" {
    content = "${tls_locally_signed_cert.service-accounts.cert_pem}"
    destination = "/etc/kube-certs/service-accounts.pem"
  }

  provisioner "file" {
    content = "${tls_private_key.service-accounts.private_key_pem}"
    destination = "/etc/kube-certs/service-accounts-key.pem"
  }

  count = "${var.kube_control_count}"
}

# Provision the Kube Workers
resource "null_resource" "kube_worker_provision" {
  connection {
    host = "${packet_device.kube_worker.*.access_public_ipv4[count.index]}"
  }

  triggers {
    host_id = "${packet_device.kube_worker.*.id[count.index]}"
    cert_ids = "${tls_self_signed_cert.root.id},${tls_locally_signed_cert.worker.*.id[count.index]}"
    key_ids = "${tls_private_key.worker.id}"
  }

  provisioner "remote-exec" {
    inline = [ "mkdir -p /etc/kube-certs" ]
  }

  provisioner "file" {
    content = "${tls_self_signed_cert.root.cert_pem}"
    destination = "/etc/kube-certs/ca.pem"
  }

  provisioner "file" {
    content = "${tls_locally_signed_cert.worker.*.cert_pem[count.index]}"
    destination = "/etc/kube-certs/kubewrk-${count.index + 1}.pem"
  }

  provisioner "file" {
    content = "${tls_private_key.worker.private_key_pem}"
    destination = "/etc/kube-certs/kubewrk-${count.index + 1}-key.pem"
  }

  count            = "${var.kube_worker_count}"
}

# Record IPs
resource "null_resource" "ips" {
  triggers {
    host_id = "${join(",", packet_device.kube_worker.*.id)},${join(",", packet_device.kube_control.*.id)}"
  }

  provisioner "local-exec" {
    command = "echo ${join(" ", packet_device.kube_worker.*.access_public_ipv4)} > worker_ips.txt" 
  }

  provisioner "local-exec" {
    command = "echo ${join(" ", packet_device.kube_control.*.access_public_ipv4)} > control_ips.txt" 
  }
}
