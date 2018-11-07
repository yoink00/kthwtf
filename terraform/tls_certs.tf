provider "tls" {}

# CA Root Key
resource "tls_private_key" "root" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# CA Root Certificate
resource "tls_self_signed_cert" "root" {
  key_algorithm         = "${tls_private_key.root.algorithm}"
  private_key_pem       = "${tls_private_key.root.private_key_pem}"


  validity_period_hours = 26280
  early_renewal_hours   = 8760

  is_ca_certificate     = true

  allowed_uses          = "${var.kube_key_uses}"

  subject {
    common_name         = "Example Ltd. Root"
    organization        = "Example, Ltd"
    organizational_unit = "CA Unit"
    street_address      = ["123 High Street"]
    locality            = "Notown"
    province            = "Noshire"
    country             = "UK"
    postal_code         = "NO12 3WH"
  }
}

# Admin Root Key
resource "tls_private_key" "admin" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Admin Certificate Request
resource "tls_cert_request" "admin" {
  key_algorithm   = "${tls_private_key.admin.algorithm}"
  private_key_pem = "${tls_private_key.admin.private_key_pem}"

  subject {
    common_name = "admin"
    organization = "system:masters"
    organizational_unit = "KTHWTF"
  }
}

# Admin Signed Certificate
resource "tls_locally_signed_cert" "admin" {
  cert_request_pem = "${tls_cert_request.admin.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

# Worker Root Key
resource "tls_private_key" "worker" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Worker Certificate Request
resource "tls_cert_request" "worker" {
  key_algorithm   = "${tls_private_key.worker.algorithm}"
  private_key_pem = "${tls_private_key.worker.private_key_pem}"

  subject {
    common_name = "system:node:kubewrk-${count.index + 1}"
    organization = "system:nodes"
    organizational_unit = "KTHWTF"
  }

  dns_names = ["${packet_device.kube_worker.*.hostname[count.index]}"]
  ip_addresses = ["${packet_device.kube_worker.*.access_private_ipv4[count.index]}", "${packet_device.kube_worker.*.access_public_ipv4[count.index]}"]

  count = "${var.kube_worker_count}"
}

# Worker Signed Certificate
resource "tls_locally_signed_cert" "worker" {
  cert_request_pem = "${tls_cert_request.worker.*.cert_request_pem[count.index]}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"

  count = "${var.kube_worker_count}"
}

# Kube Controller Manager Root Key
resource "tls_private_key" "kube-ctl-manager" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Kube Controller Manager Certificate Request
resource "tls_cert_request" "kube-ctl-manager" {
  key_algorithm   = "${tls_private_key.kube-ctl-manager.algorithm}"
  private_key_pem = "${tls_private_key.kube-ctl-manager.private_key_pem}"

  subject {
    common_name = "system:kube-controller-manager"
    organization = "system:kube-controller-manager"
    organizational_unit = "KTHWTF"
  }
}

# Kube Controller Manager Signed Certificate
resource "tls_locally_signed_cert" "kube-ctl-manager" {
  cert_request_pem = "${tls_cert_request.kube-ctl-manager.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

# Kube Proxy Manager Root Key
resource "tls_private_key" "kube-proxy-manager" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Kube Proxy Manager Certificate Request
resource "tls_cert_request" "kube-proxy-manager" {
  key_algorithm   = "${tls_private_key.kube-proxy-manager.algorithm}"
  private_key_pem = "${tls_private_key.kube-proxy-manager.private_key_pem}"

  subject {
    common_name = "system:kube-proxy"
    organization = "system:node-proxier"
    organizational_unit = "KTHWTF"
  }
}

# Kube Proxy Manager Signed Certificate
resource "tls_locally_signed_cert" "kube-proxy-manager" {
  cert_request_pem = "${tls_cert_request.kube-proxy-manager.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

# Kube Scheduler Root Key
resource "tls_private_key" "kube-scheduler" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Kube Scheduler Certificate Request
resource "tls_cert_request" "kube-scheduler" {
  key_algorithm   = "${tls_private_key.kube-scheduler.algorithm}"
  private_key_pem = "${tls_private_key.kube-scheduler.private_key_pem}"

  subject {
    common_name = "system:kube-scheduler"
    organization = "system:kube-scheduler"
    organizational_unit = "KTHWTF"
  }
}

# Kube Scheduler Signed Certificate
resource "tls_locally_signed_cert" "kube-scheduler" {
  cert_request_pem = "${tls_cert_request.kube-scheduler.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

# Kube API Server Root Key
resource "tls_private_key" "kubernetes-api" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Kube API Server Certificate Request
resource "tls_cert_request" "kubernetes-api" {
  key_algorithm   = "${tls_private_key.kubernetes-api.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes-api.private_key_pem}"

  subject {
    common_name = "kubernetes"
    organization = "Kubernetes"
    organizational_unit = "KTHWTF"
  }

  dns_names = ["${packet_device.kube_control.*.hostname}"]
  ip_addresses = ["${concat(packet_device.kube_control.*.access_public_ipv4, packet_device.kube_control.*.access_private_ipv4)}"]
}

# Kube API Server Signed Certificate
resource "tls_locally_signed_cert" "kubernetes-api" {
  cert_request_pem = "${tls_cert_request.kubernetes-api.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

# Kube Service Account Root Key
resource "tls_private_key" "service-accounts" {
  algorithm        = "ECDSA"
  ecdsa_curve      = "P521"
}

# Kube Service Account Certificate Request
resource "tls_cert_request" "service-accounts" {
  key_algorithm   = "${tls_private_key.service-accounts.algorithm}"
  private_key_pem = "${tls_private_key.service-accounts.private_key_pem}"

  subject {
    common_name = "service-accounts"
    organization = "Kubernetes"
    organizational_unit = "KTHWTF"
  }
}

# Kube Service Account Signed Certificate
resource "tls_locally_signed_cert" "service-accounts" {
  cert_request_pem = "${tls_cert_request.service-accounts.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses          = "${var.kube_key_uses}"
}

