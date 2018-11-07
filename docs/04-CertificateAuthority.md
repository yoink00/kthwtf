# Provisioning Compute Resources

> Note: A list of sources can be found at the end of this post.

## Overview

This post is heavily derived from Kelsey Hightower's Kubernetes the Hard Way but has been changed to use [Packet](https://www.packet.com), [Terraform](https://www.terraform.io) and [Ansible](https://www.ansible.com)

In this lab we will provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) using [Terraform's TLS provider](https://www.terraform.io/docs/providers/tls/), then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

## Variables

These resources will use the previously defined variables as well as requiring a new variable. Add this to the `variables.tf` file:

```
variable "kube_key_uses" {
  default = ["cert_signing", "client_auth", "server_auth", "key_encipherment"]
}
```

This defines the allowed uses of our keys and prevents a bit of repitition.

## Certificate Authority

In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.

Generate the CA configuration file, certificate, and private key using the TLS provider by adding the following to a new `tls_certs.tf` file:

```
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
```

Run:

```
terraform plan
```

The output should look like (removing compute resources for brevity):

```
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  ...
  ...

  + tls_private_key.root
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_self_signed_cert.root
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      cert_pem:                      <computed>
      early_renewal_hours:           "8760"
      is_ca_certificate:             "true"
      key_algorithm:                 "ECDSA"
      private_key_pem:               "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      subject.#:                     "1"
      subject.0.common_name:         "Example Ltd. Root"
      subject.0.country:             "UK"
      subject.0.locality:            "Notown"
      subject.0.organization:        "Example, Ltd"
      subject.0.organizational_unit: "CA Unit"
      subject.0.postal_code:         "NO12 3WH"
      subject.0.province:            "Noshire"
      subject.0.street_address.#:    "1"
      subject.0.street_address.0:    "123 High Street"
      validity_end_time:             <computed>
      validity_period_hours:         "26280"
      validity_start_time:           <computed>


Plan: 9 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.

```

## Client and Server Certificates

In this section you will generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes `admin` user.

### The Admin Client Certificate

Generate the `admin` client certificate and private key by adding the following to the `tls_certs.tf` file:

```
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
```

Run:

```
terraform plan
```

The output should look like (abbreviated):

```
...
...
  + tls_cert_request.admin
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "24b5aa31a1e81bf4da5c109fbab8d5d31fbeb5ab"
      subject.#:                     "1"
      subject.0.common_name:         "admin"
      subject.0.organization:        "system:masters"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.admin
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "76939136e2b18977468c6140d7d43ea1ad589284"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.admin
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```

### The Kubelet Client Certificates

Kubernetes uses a [special-purpose authorization mode](https://kubernetes.io/docs/admin/authorization/node/) called Node Authorizer, that specifically authorizes API requests made by [Kubelets](https://kubernetes.io/docs/concepts/overview/components/#kubelet). In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.

Generate a certificate and private key for each Kubernetes worker node by adding the following to the `tls_certs.tf` file:

```
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
```

Run:

```
terraform plan
```

The output should look like (abbreviated):

```
...
...
  + tls_cert_request.worker[0]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-1"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-1"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.worker[1]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-2"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-2"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.worker[2]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-3"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-3"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.worker[0]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.worker[1]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.worker[2]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.worker
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```

### The Controller Manager Client Certificate

Generate the `kube-controller-manager` client certificate and private key by adding the following to `tls_certs.tf`:

```
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
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + tls_cert_request.kube-ctl-manager
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "98107467bdd4755232f62a8c602d6704912e39a1"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-controller-manager"
      subject.0.organization:        "system:kube-controller-manager"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.kube-ctl-manager
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "17b79843253fa772a6ae4ce75a1bbbca80369f1c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.kube-ctl-manager
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```


### The Kube Proxy Client Certificate

Generate the `kube-proxy` client certificate and private key by adding the following to `tls_certs.tf`:

```
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
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + tls_cert_request.kube-proxy-manager
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "3a64b4b71d972ed53681a0dbbb80b6f44dfff27a"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-proxy"
      subject.0.organization:        "system:node-proxier"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.kube-proxy-manager
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "e7efb778038ee076b1005055937947aaab4fe1ad"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.kube-proxy-manager
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```

### The Scheduler Client Certificate

Generate the `kube-scheduler` client certificate and private key:

```
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
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + tls_cert_request.kube-scheduler
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "cd7be11e32e1085210bdec175c0e5ff6bf087e44"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-scheduler"
      subject.0.organization:        "system:kube-scheduler"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.kube-scheduler
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "28b0dea4d435155f7e8fab9b6aa852c29528166e"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.kube-scheduler
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```


### The Kubernetes API Server Certificate

The `kubernetes-the-hard-way` static IP addresses will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.

Generate the Kubernetes API Server certificate and private key by adding the following to `tls_certs.tf`

```
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
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + tls_cert_request.kubernetes-api
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "3"
      dns_names.0:                   "kubectl-1"
      dns_names.1:                   "kubectl-2"
      dns_names.2:                   "kubectl-3"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "6ada099c51fcb031b96cf8800bfe150f17666054"
      subject.#:                     "1"
      subject.0.common_name:         "kubernetes"
      subject.0.organization:        "Kubernetes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.kubernetes-api
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "11019897818ae09f3e710c337af81a264ea18f5d"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.kubernetes-api
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```

## The Service Account Key Pair

The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as describe in the [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/) documentation.

Generate the `service-account` certificate and private key by adding the following to `tls_certs.tf`:

```
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
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + tls_cert_request.service-accounts
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "657a2c1fdce24a2962978fa9625db7cf8a55a89f"
      subject.#:                     "1"
      subject.0.common_name:         "service-accounts"
      subject.0.organization:        "Kubernetes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.service-accounts
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "4bad47a6d77bffb7e8ab0f7ef150e1b91f407ba1"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.service-accounts
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"
...
...
```

## Distribute the Client and Server Certificates

We now need to copy the appropriate certificates and private keys to each worker instance. Terraform supports a number of provisioners which are run once a resource is created.

Normally a provisioner is specified as part of the resource itself but in our case we have a cyclic dependency. Our compute resource provisioners depend on the certificates we've generated but the certificates depend on the IP addresses of our compute resources which are only available after the resource is created.

Thankfully Terraform supports the [`null_resource`](https://www.terraform.io/docs/providers/null/resource.html) resource as part of the `Null` provider. This allows us to break the cycle by moving the provisioning to these null resources. We can specify the dependencies using Terraform's interpolation syntax and the hosts to connect to in `connection` blocks. 

To deploy the Worker certificates add the following to `provision.tf`:

```
# Use the "null" provider
provider "null" {}

# Provision the Kube Workers
resource "null_resource" "kube_worker_provision" {
  # For each worker we've created use it's IPv4 address
  # as the SSH host to connect to for provisioning.
  connection {
    host = "${packet_device.kube_worker.*.access_public_ipv4[count.index]}"
  }

  # Triggers ensure that this resource is rerun if the host,
  # certificates, or keys change.
  triggers {
    host_id = "${packet_device.kube_worker.*.id[count.index]}"
    cert_ids = "${tls_self_signed_cert.root.id},${tls_locally_signed_cert.worker.*.id[count.index]}"
    key_ids = "${tls_private_key.worker.id}"
  }

  # Make directory on the remote server for the certificates to live in
  provisioner "remote-exec" {
    inline = [ "mkdir -p /etc/kube-certs" ]
  }

  # Copy the CA certificate
  provisioner "file" {
    content = "${tls_self_signed_cert.root.cert_pem}"
    destination = "/etc/kube-certs/ca.pem"
  }

  # Copy the worker's public certificate
  provisioner "file" {
    content = "${tls_locally_signed_cert.worker.*.cert_pem[count.index]}"
    destination = "/etc/kube-certs/kubewrk-${count.index + 1}.pem"
  }

  # Copy the worker's private key
  provisioner "file" {
    content = "${tls_private_key.worker.private_key_pem}"
    destination = "/etc/kube-certs/kubewrk-${count.index + 1}-key.pem"
  }

  # Create this "null_resource" for each worker we've created
  count            = "${var.kube_worker_count}"
}
```

To copy the appropriate certificates and private keys to each controller instance add the following to the `provision.tf` file:

```
# Provision the Kube Controllers
resource "null_resource" "kube_control_provision" {
  # For each controller we've created use it's IPv4 address
  # as the SSH host to connect to for provisioning.
  connection {
    host = "${packet_device.kube_control.*.access_public_ipv4[count.index]}"
  }

  # Triggers ensure that this resource is rerun if the host,
  # certificates, or keys change.
  triggers {
    host_id = "${packet_device.kube_control.*.id[count.index]}"
    cert_ids = "${tls_self_signed_cert.root.id},${tls_locally_signed_cert.kubernetes-api.id},${tls_locally_signed_cert.service-accounts.id}"
    key_ids = "${tls_private_key.root.id},${tls_private_key.kubernetes-api.id},${tls_private_key.service-accounts.id}"
  }

  # Make directory on the remote server for the certificates to live in
  provisioner "remote-exec" {
    inline = [ "mkdir -p /etc/kube-certs" ]
  }

 # Copy the CA certificate
  provisioner "file" {
    content = "${tls_self_signed_cert.root.cert_pem}"
    destination = "/etc/kube-certs/ca.pem"
  }

  # Copy the CA's private key
  provisioner "file" {
    content = "${tls_private_key.root.private_key_pem}"
    destination = "/etc/kube-certs/ca-key.pem"
  }

  # Copy the Kubernetes API certificate
  provisioner "file" {
    content = "${tls_locally_signed_cert.kubernetes-api.cert_pem}"
    destination = "/etc/kube-certs/kubernetes.pem"
  }

  # Copy the Kubernetes API private key
  provisioner "file" {
    content = "${tls_private_key.kubernetes-api.private_key_pem}"
    destination = "/etc/kube-certs/kubernetes-key.pem"
  }

  # Copy the Service Accounts certificate
  provisioner "file" {
    content = "${tls_locally_signed_cert.service-accounts.cert_pem}"
    destination = "/etc/kube-certs/service-accounts.pem"
  }

  # Copy the Service Accounts private key
  provisioner "file" {
    content = "${tls_private_key.service-accounts.private_key_pem}"
    destination = "/etc/kube-certs/service-accounts-key.pem"
  }

  # Create this "null_resource" for each controller we've created
  count = "${var.kube_control_count}"
}
```

Run:

```
terraform plan
```

Output (abbreviated):

```
...
...
  + null_resource.kube_control_provision[0]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_control_provision[1]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_control_provision[2]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[0]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[1]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[2]
      id:                            <computed>
      triggers.%:                    <computed>
...
...
```

If the output of `terraform plan` looks as we are expecting we are now ready to try our new Terraform configuration. Run:

```
terraform apply
```

This will take about 6 minutes or so. Output (abbreviated):

```
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + null_resource.kube_control_provision[0]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_control_provision[1]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_control_provision[2]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[0]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[1]
      id:                            <computed>
      triggers.%:                    <computed>

  + null_resource.kube_worker_provision[2]
      id:                            <computed>
      triggers.%:                    <computed>

  + packet_device.kube_control[0]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubectl-1"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      updated:                       <computed>

  + packet_device.kube_control[1]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubectl-2"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      updated:                       <computed>

  + packet_device.kube_control[2]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubectl-3"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      updated:                       <computed>

  + packet_device.kube_worker[0]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubewrk-1"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      tags.#:                        "1"
      tags.0:                        "pod-cidr=192.168.1.0/24"
      updated:                       <computed>

  + packet_device.kube_worker[1]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubewrk-2"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      tags.#:                        "1"
      tags.0:                        "pod-cidr=192.168.2.0/24"
      updated:                       <computed>

  + packet_device.kube_worker[2]
      id:                            <computed>
      access_private_ipv4:           <computed>
      access_public_ipv4:            <computed>
      access_public_ipv6:            <computed>
      always_pxe:                    "false"
      billing_cycle:                 "hourly"
      created:                       <computed>
      facility:                      "ams1"
      hardware_reservation_id:       <computed>
      hostname:                      "kubewrk-3"
      locked:                        <computed>
      network.#:                     <computed>
      operating_system:              "ubuntu_18_04"
      plan:                          "baremetal_0"
      project_id:                    "${packet_project.kthwtf.id}"
      public_ipv4_subnet_size:       <computed>
      root_password:                 <computed>
      state:                         <computed>
      tags.#:                        "1"
      tags.0:                        "pod-cidr=192.168.3.0/24"
      updated:                       <computed>

  + packet_project.kthwtf
      id:                            <computed>
      created:                       <computed>
      name:                          "Kubernetes the Hard Way with Terraform"
      updated:                       <computed>

  + tls_cert_request.admin
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "24b5aa31a1e81bf4da5c109fbab8d5d31fbeb5ab"
      subject.#:                     "1"
      subject.0.common_name:         "admin"
      subject.0.organization:        "system:masters"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.kube-ctl-manager
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "98107467bdd4755232f62a8c602d6704912e39a1"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-controller-manager"
      subject.0.organization:        "system:kube-controller-manager"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.kube-proxy-manager
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "3a64b4b71d972ed53681a0dbbb80b6f44dfff27a"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-proxy"
      subject.0.organization:        "system:node-proxier"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.kube-scheduler
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "cd7be11e32e1085210bdec175c0e5ff6bf087e44"
      subject.#:                     "1"
      subject.0.common_name:         "system:kube-scheduler"
      subject.0.organization:        "system:kube-scheduler"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.kubernetes-api
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "3"
      dns_names.0:                   "kubectl-1"
      dns_names.1:                   "kubectl-2"
      dns_names.2:                   "kubectl-3"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "6ada099c51fcb031b96cf8800bfe150f17666054"
      subject.#:                     "1"
      subject.0.common_name:         "kubernetes"
      subject.0.organization:        "Kubernetes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.service-accounts
      id:                            <computed>
      cert_request_pem:              <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "657a2c1fdce24a2962978fa9625db7cf8a55a89f"
      subject.#:                     "1"
      subject.0.common_name:         "service-accounts"
      subject.0.organization:        "Kubernetes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.worker[0]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-1"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-1"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.worker[1]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-2"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-2"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_cert_request.worker[2]
      id:                            <computed>
      cert_request_pem:              <computed>
      dns_names.#:                   "1"
      dns_names.0:                   "kubewrk-3"
      ip_addresses.#:                <computed>
      key_algorithm:                 "ECDSA"
      private_key_pem:               "8c5938595c6221803a2b3c8e93dd82bf08246025"
      subject.#:                     "1"
      subject.0.common_name:         "system:node:kubewrk-3"
      subject.0.organization:        "system:nodes"
      subject.0.organizational_unit: "KTHWTF"

  + tls_locally_signed_cert.admin
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "76939136e2b18977468c6140d7d43ea1ad589284"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.kube-ctl-manager
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "17b79843253fa772a6ae4ce75a1bbbca80369f1c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.kube-proxy-manager
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "e7efb778038ee076b1005055937947aaab4fe1ad"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.kube-scheduler
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "28b0dea4d435155f7e8fab9b6aa852c29528166e"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.kubernetes-api
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "11019897818ae09f3e710c337af81a264ea18f5d"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.service-accounts
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "4bad47a6d77bffb7e8ab0f7ef150e1b91f407ba1"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.worker[0]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.worker[1]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_locally_signed_cert.worker[2]
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      ca_cert_pem:                   "73dc20cf687f65147328fef38ee7af96dc1f262f"
      ca_key_algorithm:              "ECDSA"
      ca_private_key_pem:            "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      cert_pem:                      <computed>
      cert_request_pem:              "178fa64bc0f4ce975c4b4214f3b8da7821125d5c"
      early_renewal_hours:           "8760"
      validity_end_time:             <computed>
      validity_period_hours:         "17520"
      validity_start_time:           <computed>

  + tls_private_key.admin
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.kube-ctl-manager
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.kube-proxy-manager
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.kube-scheduler
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.kubernetes-api
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.root
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.service-accounts
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_private_key.worker
      id:                            <computed>
      algorithm:                     "ECDSA"
      ecdsa_curve:                   "P521"
      private_key_pem:               <computed>
      public_key_fingerprint_md5:    <computed>
      public_key_openssh:            <computed>
      public_key_pem:                <computed>
      rsa_bits:                      "2048"

  + tls_self_signed_cert.root
      id:                            <computed>
      allowed_uses.#:                "4"
      allowed_uses.0:                "cert_signing"
      allowed_uses.1:                "client_auth"
      allowed_uses.2:                "server_auth"
      allowed_uses.3:                "key_encipherment"
      cert_pem:                      <computed>
      early_renewal_hours:           "8760"
      is_ca_certificate:             "true"
      key_algorithm:                 "ECDSA"
      private_key_pem:               "3171bea522421d4a991b46f2f9f5e5ceb6410825"
      subject.#:                     "1"
      subject.0.common_name:         "Example Ltd. Root"
      subject.0.country:             "UK"
      subject.0.locality:            "Notown"
      subject.0.organization:        "Example, Ltd"
      subject.0.organizational_unit: "CA Unit"
      subject.0.postal_code:         "NO12 3WH"
      subject.0.province:            "Noshire"
      subject.0.street_address.#:    "1"
      subject.0.street_address.0:    "123 High Street"
      validity_end_time:             <computed>
      validity_period_hours:         "26280"
      validity_start_time:           <computed>


Plan: 40 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes 

tls_private_key.worker: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.kubernetes-api: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.admin: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
packet_project.kthwtf: Creating...
  created: "" => "<computed>"
  name:    "" => "Kubernetes the Hard Way with Terraform"
  updated: "" => "<computed>"
tls_private_key.root: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.kube-ctl-manager: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.service-accounts: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.kube-proxy-manager: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.kube-scheduler: Creating...
  algorithm:                  "" => "ECDSA"
  ecdsa_curve:                "" => "P521"
  private_key_pem:            "" => "<computed>"
  public_key_fingerprint_md5: "" => "<computed>"
  public_key_openssh:         "" => "<computed>"
  public_key_pem:             "" => "<computed>"
  rsa_bits:                   "" => "2048"
tls_private_key.admin: Creation complete after 0s (ID: c3d123938130cc876bf8140b79528f33bd98bfdf)
tls_private_key.worker: Creation complete after 0s (ID: 08271aa90e1b6b9f06f33cc400e078a3a1dbcd52)
tls_private_key.kubernetes-api: Creation complete after 0s (ID: 9a3355c2af134a5a39ea9f3ec0dfa9d84753aed9)
tls_private_key.root: Creation complete after 0s (ID: 5f59aaa3883964df0d659d3e8d63f4f9ae5cb6a7)
tls_private_key.kube-ctl-manager: Creation complete after 0s (ID: 639338e42ca54dd02891bff068121d1c1d854d5f)
tls_cert_request.admin: Creating...
  cert_request_pem:              "" => "<computed>"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "5e58a45b9075f0e1b0afbc06827236c236f05be1"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "admin"
  subject.0.organization:        "" => "system:masters"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_private_key.kube-scheduler: Creation complete after 0s (ID: 9a4d32540621c78e9e3ce1809d00e03f3747ba6f)
tls_private_key.service-accounts: Creation complete after 0s (ID: 18121be6eea2e55053dfc2ddab5f79025e896d75)
tls_private_key.kube-proxy-manager: Creation complete after 0s (ID: 1cf2c87bb908eef07c1672cd957089518f433200)
tls_cert_request.kube-scheduler: Creating...
  cert_request_pem:              "" => "<computed>"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "ee7d6cc71cfcc63249120eb4c9333b35a835e606"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:kube-scheduler"
  subject.0.organization:        "" => "system:kube-scheduler"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_self_signed_cert.root: Creating...
  allowed_uses.#:                "" => "4"
  allowed_uses.0:                "" => "cert_signing"
  allowed_uses.1:                "" => "client_auth"
  allowed_uses.2:                "" => "server_auth"
  allowed_uses.3:                "" => "key_encipherment"
  cert_pem:                      "" => "<computed>"
  early_renewal_hours:           "" => "8760"
  is_ca_certificate:             "" => "true"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "Example Ltd. Root"
  subject.0.country:             "" => "UK"
  subject.0.locality:            "" => "Notown"
  subject.0.organization:        "" => "Example, Ltd"
  subject.0.organizational_unit: "" => "CA Unit"
  subject.0.postal_code:         "" => "NO12 3WH"
  subject.0.province:            "" => "Noshire"
  subject.0.street_address.#:    "" => "1"
  subject.0.street_address.0:    "" => "123 High Street"
  validity_end_time:             "" => "<computed>"
  validity_period_hours:         "" => "26280"
  validity_start_time:           "" => "<computed>"
tls_cert_request.kube-ctl-manager: Creating...
  cert_request_pem:              "" => "<computed>"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "08009278aae3eeaa7b9c6aef3f3202e9022fce69"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:kube-controller-manager"
  subject.0.organization:        "" => "system:kube-controller-manager"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.service-accounts: Creating...
  cert_request_pem:              "" => "<computed>"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "526de6b5abad6fbabe2b89ffb1d894a95ef11072"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "service-accounts"
  subject.0.organization:        "" => "Kubernetes"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.kube-proxy-manager: Creating...
  cert_request_pem:              "" => "<computed>"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "98d658d43c549aaf71c1ce67a69dee7e77614067"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:kube-proxy"
  subject.0.organization:        "" => "system:node-proxier"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.admin: Creation complete after 0s (ID: fd3b2c4f15546d262d9f46d8db932eaa953763a8)
tls_cert_request.kube-scheduler: Creation complete after 0s (ID: 725c345b88df3bc76947e2063ed61a0dad5b665d)
tls_self_signed_cert.root: Creation complete after 0s (ID: 320176956810783010284899869505088686754)
tls_cert_request.kube-proxy-manager: Creation complete after 0s (ID: d437425f3c949595390dc882ea2c8caf308b7e34)
tls_cert_request.kube-ctl-manager: Creation complete after 0s (ID: 915d2d06b6e7adbf6838f923bcffab41982db560)
tls_cert_request.service-accounts: Creation complete after 0s (ID: edaa061880ecaf10dfd986e913cb867ab1ab55d6)
tls_locally_signed_cert.kube-scheduler: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "7ab725936c77bffe40495c3d2b353353a8e5df99"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.kube-ctl-manager: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "06202612cfd36d5f23c1096cd5fdda0fe7d30d08"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.admin: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "02e42d55298ea18f488c104192ee15cde3764e39"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.kube-proxy-manager: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "bb7e971425360e1198d8791b4ef1fe48d56bc662"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.service-accounts: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "12c1b270e22efedd17badfb07a76cc74ee109f86"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.kube-proxy-manager: Creation complete after 0s (ID: 79080965961406914126332482834202571400)
tls_locally_signed_cert.kube-scheduler: Creation complete after 0s (ID: 64620465874141020017400452055509145184)
tls_locally_signed_cert.admin: Creation complete after 0s (ID: 304969067101942090352537094808713728327)
tls_locally_signed_cert.kube-ctl-manager: Creation complete after 0s (ID: 37643178836704388444044597714132787850)
tls_locally_signed_cert.service-accounts: Creation complete after 0s (ID: 296264572517428928465066387489852009760)
packet_project.kthwtf: Creation complete after 2s (ID: b206bd72-ccaa-4a55-831d-a556ed24b885)
packet_device.kube_control[2]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubectl-3"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  updated:                 "" => "<computed>"
packet_device.kube_control[0]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubectl-1"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  updated:                 "" => "<computed>"
packet_device.kube_worker[0]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubewrk-1"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.1.0/24"
  updated:                 "" => "<computed>"
packet_device.kube_control[1]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubectl-2"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  updated:                 "" => "<computed>"
packet_device.kube_worker[2]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubewrk-3"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.3.0/24"
  updated:                 "" => "<computed>"
packet_device.kube_worker[1]: Creating...
  access_private_ipv4:     "" => "<computed>"
  access_public_ipv4:      "" => "<computed>"
  access_public_ipv6:      "" => "<computed>"
  always_pxe:              "" => "false"
  billing_cycle:           "" => "hourly"
  created:                 "" => "<computed>"
  facility:                "" => "ams1"
  hardware_reservation_id: "" => "<computed>"
  hostname:                "" => "kubewrk-2"
  locked:                  "" => "<computed>"
  network.#:               "" => "<computed>"
  operating_system:        "" => "ubuntu_18_04"
  plan:                    "" => "baremetal_0"
  project_id:              "" => "b206bd72-ccaa-4a55-831d-a556ed24b885"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.2.0/24"
  updated:                 "" => "<computed>"
packet_device.kube_control.2: Still creating... (10s elapsed)
packet_device.kube_control.0: Still creating... (10s elapsed)
packet_device.kube_worker.0: Still creating... (10s elapsed)
packet_device.kube_control.1: Still creating... (10s elapsed)
packet_device.kube_worker.2: Still creating... (10s elapsed)
packet_device.kube_worker.1: Still creating... (10s elapsed)
...
...
packet_device.kube_worker[1]: Creation complete after 7m35s (ID: 79b70c67-3fa6-46fe-8afc-090bd43274d2)
...
...
packet_device.kube_control[0]: Creation complete after 7m46s (ID: 292ef365-e64e-4de2-b572-166e98b5767a)
packet_device.kube_worker[2]: Creation complete after 7m48s (ID: 9878bedc-08d5-432f-bc9f-1ec5dd6fcd2e)
...
...
packet_device.kube_worker[0]: Creation complete after 7m52s (ID: 8e8a84be-0b5d-4832-a737-70164969fbf0)
tls_cert_request.worker[2]: Creating...
  cert_request_pem:              "" => "<computed>"
  dns_names.#:                   "" => "1"
  dns_names.0:                   "" => "kubewrk-3"
  ip_addresses.#:                "" => "2"
  ip_addresses.0:                "" => "10.80.134.135"
  ip_addresses.1:                "" => "147.75.205.71"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "94336becb063d67530ab19a954f7a87e636e9452"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:node:kubewrk-3"
  subject.0.organization:        "" => "system:nodes"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.worker[1]: Creating...
  cert_request_pem:              "" => "<computed>"
  dns_names.#:                   "" => "1"
  dns_names.0:                   "" => "kubewrk-2"
  ip_addresses.#:                "" => "2"
  ip_addresses.0:                "" => "10.80.134.129"
  ip_addresses.1:                "" => "147.75.33.239"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "94336becb063d67530ab19a954f7a87e636e9452"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:node:kubewrk-2"
  subject.0.organization:        "" => "system:nodes"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.worker[0]: Creating...
  cert_request_pem:              "" => "<computed>"
  dns_names.#:                   "" => "1"
  dns_names.0:                   "" => "kubewrk-1"
  ip_addresses.#:                "" => "2"
  ip_addresses.0:                "" => "10.80.134.139"
  ip_addresses.1:                "" => "147.75.100.219"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "94336becb063d67530ab19a954f7a87e636e9452"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "system:node:kubewrk-1"
  subject.0.organization:        "" => "system:nodes"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.worker[2]: Creation complete after 0s (ID: e9360b443815f4fb71092a4382bc57f4f90cc8d5)
tls_cert_request.worker[1]: Creation complete after 0s (ID: c19e05386129217a6d5968fcb20ef65a796565c8)
tls_cert_request.worker[0]: Creation complete after 0s (ID: 4e9cdf0946509bcb9562c4d995e5c1bc980fd348)
tls_locally_signed_cert.worker[0]: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "34d53b5b104a3dabfea6cd5f72523e8932e888b9"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.worker[2]: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "c517666f15c681bea60fe3da1f12306575b11d75"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.worker[1]: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "edcf9be26c1edd60fa095742e21b245958f0ab76"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.worker[0]: Creation complete after 0s (ID: 3422940532513029276668059472001017514)
tls_locally_signed_cert.worker[1]: Creation complete after 0s (ID: 52672677127951185552022842868788220888)
tls_locally_signed_cert.worker[2]: Creation complete after 0s (ID: 116645161107331777960042975621241007834)
null_resource.kube_worker_provision[1]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,52672677127951185552022842868788220888"
  triggers.host_id:  "" => "79b70c67-3fa6-46fe-8afc-090bd43274d2"
  triggers.key_ids:  "" => "08271aa90e1b6b9f06f33cc400e078a3a1dbcd52"
null_resource.kube_worker_provision[2]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,116645161107331777960042975621241007834"
  triggers.host_id:  "" => "9878bedc-08d5-432f-bc9f-1ec5dd6fcd2e"
  triggers.key_ids:  "" => "08271aa90e1b6b9f06f33cc400e078a3a1dbcd52"
null_resource.kube_worker_provision[0]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,3422940532513029276668059472001017514"
  triggers.host_id:  "" => "8e8a84be-0b5d-4832-a737-70164969fbf0"
  triggers.key_ids:  "" => "08271aa90e1b6b9f06f33cc400e078a3a1dbcd52"
null_resource.kube_worker_provision[2]: Provisioning with 'remote-exec'...
null_resource.kube_worker_provision[1]: Provisioning with 'remote-exec'...
null_resource.kube_worker_provision[0]: Provisioning with 'remote-exec'...
null_resource.kube_worker_provision[2] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_worker_provision[2] (remote-exec):   Host: 147.75.205.71
null_resource.kube_worker_provision[2] (remote-exec):   User: root
null_resource.kube_worker_provision[2] (remote-exec):   Password: false
null_resource.kube_worker_provision[2] (remote-exec):   Private key: false
null_resource.kube_worker_provision[2] (remote-exec):   SSH Agent: true
null_resource.kube_worker_provision[2] (remote-exec):   Checking Host Key: false
null_resource.kube_worker_provision[0] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_worker_provision[0] (remote-exec):   Host: 147.75.100.219
null_resource.kube_worker_provision[0] (remote-exec):   User: root
null_resource.kube_worker_provision[0] (remote-exec):   Password: false
null_resource.kube_worker_provision[0] (remote-exec):   Private key: false
null_resource.kube_worker_provision[0] (remote-exec):   SSH Agent: true
null_resource.kube_worker_provision[0] (remote-exec):   Checking Host Key: false
null_resource.kube_worker_provision[1] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_worker_provision[1] (remote-exec):   Host: 147.75.33.239
null_resource.kube_worker_provision[1] (remote-exec):   User: root
null_resource.kube_worker_provision[1] (remote-exec):   Password: false
null_resource.kube_worker_provision[1] (remote-exec):   Private key: false
null_resource.kube_worker_provision[1] (remote-exec):   SSH Agent: true
null_resource.kube_worker_provision[1] (remote-exec):   Checking Host Key: false
null_resource.kube_worker_provision[2] (remote-exec): Connected!
null_resource.kube_worker_provision[1] (remote-exec): Connected!
null_resource.kube_worker_provision[0] (remote-exec): Connected!
null_resource.kube_worker_provision[1]: Provisioning with 'file'...
null_resource.kube_worker_provision[2]: Provisioning with 'file'...
null_resource.kube_worker_provision[0]: Provisioning with 'file'...
...
...
null_resource.kube_worker_provision[1]: Creation complete after 4s (ID: 1805964476526504309)
null_resource.kube_worker_provision[0]: Creation complete after 4s (ID: 7146815957732278359)
null_resource.kube_worker_provision[2]: Creation complete after 4s (ID: 6885926917517915709)
packet_device.kube_control.1: Still creating... (8m0s elapsed)
packet_device.kube_control.2: Still creating... (8m0s elapsed)
packet_device.kube_control[1]: Creation complete after 8m0s (ID: bc1b2f29-1260-4807-a2d1-3882fd47ef64)
packet_device.kube_control[2]: Creation complete after 8m1s (ID: 40c0a8c2-cd3b-452a-8888-a1285cdb1684)
tls_cert_request.kubernetes-api: Creating...
  cert_request_pem:              "" => "<computed>"
  dns_names.#:                   "" => "3"
  dns_names.0:                   "" => "kubectl-1"
  dns_names.1:                   "" => "kubectl-2"
  dns_names.2:                   "" => "kubectl-3"
  ip_addresses.#:                "" => "6"
  ip_addresses.0:                "" => "147.75.205.51"
  ip_addresses.1:                "" => "147.75.83.153"
  ip_addresses.2:                "" => "147.75.205.3"
  ip_addresses.3:                "" => "10.80.134.137"
  ip_addresses.4:                "" => "10.80.134.133"
  ip_addresses.5:                "" => "10.80.134.131"
  key_algorithm:                 "" => "ECDSA"
  private_key_pem:               "" => "d02ca3d1a90e2900d5b430121f1b0927dfdef611"
  subject.#:                     "" => "1"
  subject.0.common_name:         "" => "kubernetes"
  subject.0.organization:        "" => "Kubernetes"
  subject.0.organizational_unit: "" => "KTHWTF"
tls_cert_request.kubernetes-api: Creation complete after 0s (ID: 45ef7ce4b462fc9da1aba491e1b778e6cfba3693)
tls_locally_signed_cert.kubernetes-api: Creating...
  allowed_uses.#:        "" => "4"
  allowed_uses.0:        "" => "cert_signing"
  allowed_uses.1:        "" => "client_auth"
  allowed_uses.2:        "" => "server_auth"
  allowed_uses.3:        "" => "key_encipherment"
  ca_cert_pem:           "" => "50df3533014bf2e9d6315bf38f229a86f208aa2f"
  ca_key_algorithm:      "" => "ECDSA"
  ca_private_key_pem:    "" => "72ddeebeb67cb5670a5149465193a4ce16783eae"
  cert_pem:              "" => "<computed>"
  cert_request_pem:      "" => "0c07a8b4ebb21386e44f267624b1851937a90fc3"
  early_renewal_hours:   "" => "8760"
  validity_end_time:     "" => "<computed>"
  validity_period_hours: "" => "17520"
  validity_start_time:   "" => "<computed>"
tls_locally_signed_cert.kubernetes-api: Creation complete after 0s (ID: 96939440830304157581971990490000942397)
null_resource.kube_control_provision[1]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,96939440830304157581971990490000942397,296264572517428928465066387489852009760"
  triggers.host_id:  "" => "bc1b2f29-1260-4807-a2d1-3882fd47ef64"
  triggers.key_ids:  "" => "5f59aaa3883964df0d659d3e8d63f4f9ae5cb6a7,9a3355c2af134a5a39ea9f3ec0dfa9d84753aed9,18121be6eea2e55053dfc2ddab5f79025e896d75"
null_resource.kube_control_provision[0]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,96939440830304157581971990490000942397,296264572517428928465066387489852009760"
  triggers.host_id:  "" => "292ef365-e64e-4de2-b572-166e98b5767a"
  triggers.key_ids:  "" => "5f59aaa3883964df0d659d3e8d63f4f9ae5cb6a7,9a3355c2af134a5a39ea9f3ec0dfa9d84753aed9,18121be6eea2e55053dfc2ddab5f79025e896d75"
null_resource.kube_control_provision[1]: Provisioning with 'remote-exec'...
null_resource.kube_control_provision[2]: Creating...
  triggers.%:        "" => "3"
  triggers.cert_ids: "" => "320176956810783010284899869505088686754,96939440830304157581971990490000942397,296264572517428928465066387489852009760"
  triggers.host_id:  "" => "40c0a8c2-cd3b-452a-8888-a1285cdb1684"
  triggers.key_ids:  "" => "5f59aaa3883964df0d659d3e8d63f4f9ae5cb6a7,9a3355c2af134a5a39ea9f3ec0dfa9d84753aed9,18121be6eea2e55053dfc2ddab5f79025e896d75"
null_resource.kube_control_provision[0]: Provisioning with 'remote-exec'...
null_resource.kube_control_provision[2]: Provisioning with 'remote-exec'...
null_resource.kube_control_provision[1] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_control_provision[1] (remote-exec):   Host: 147.75.83.153
null_resource.kube_control_provision[1] (remote-exec):   User: root
null_resource.kube_control_provision[1] (remote-exec):   Password: false
null_resource.kube_control_provision[1] (remote-exec):   Private key: false
null_resource.kube_control_provision[1] (remote-exec):   SSH Agent: true
null_resource.kube_control_provision[1] (remote-exec):   Checking Host Key: false
null_resource.kube_control_provision[0] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_control_provision[0] (remote-exec):   Host: 147.75.205.51
null_resource.kube_control_provision[0] (remote-exec):   User: root
null_resource.kube_control_provision[0] (remote-exec):   Password: false
null_resource.kube_control_provision[0] (remote-exec):   Private key: false
null_resource.kube_control_provision[0] (remote-exec):   SSH Agent: true
null_resource.kube_control_provision[0] (remote-exec):   Checking Host Key: false
null_resource.kube_control_provision[2] (remote-exec): Connecting to remote host via SSH...
null_resource.kube_control_provision[2] (remote-exec):   Host: 147.75.205.3
null_resource.kube_control_provision[2] (remote-exec):   User: root
null_resource.kube_control_provision[2] (remote-exec):   Password: false
null_resource.kube_control_provision[2] (remote-exec):   Private key: false
null_resource.kube_control_provision[2] (remote-exec):   SSH Agent: true
null_resource.kube_control_provision[2] (remote-exec):   Checking Host Key: false
null_resource.kube_control_provision[1] (remote-exec): Connected!
null_resource.kube_control_provision[0] (remote-exec): Connected!
null_resource.kube_control_provision[2] (remote-exec): Connected!
null_resource.kube_control_provision[0]: Provisioning with 'file'...
null_resource.kube_control_provision[1]: Provisioning with 'file'...
null_resource.kube_control_provision[2]: Provisioning with 'file'...
...
...
null_resource.kube_control_provision[2]: Creation complete after 5s (ID: 193925313120534344)
null_resource.kube_control_provision[0]: Creation complete after 5s (ID: 3206204585564340471)
null_resource.kube_control_provision[1]: Creation complete after 5s (ID: 5177099251934868347)
```

### Verify Certificate Distribution

We can check the certificates are present on all the worker servers by adding a `null_resource` to get the IP addresses of the boxes and running a Bash script. First add the following to `provision.tf`:

```
# Record IPs
resource "null_resource" "ips" {
  triggers {
    host_id = "${join(",", packet_device.kube_worker.*.id)},${join(",", packet_device.kube_control.*.id)}"
  }

  provisioner "local-exec" {
    command = "echo ${join(" ", packet_device.kube_worker.*.access_public_ipv4)} > /tmp/worker_ips.txt"
  }

  provisioner "local-exec" {
    command = "echo ${join(" ", packet_device.kube_control.*.access_public_ipv4)} > /tmp control_ips.txt"
  }
}
```

The above Terraform will create two files in `/tmp`:

* `worker_ips.txt`
* `control_ips.txt`

Next, run the following Bash snippet:

```
for ip in $(cat /tmp/worker_ips.txt);do
  ssh -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no root@$ip \
      ls /etc/kube-certs
done
```

The output will look something like:

```
Warning: Permanently added '147.75.100.219' (ECDSA) to the list of known hosts.
ca.pem
kubewrk-1-key.pem
kubewrk-1.pem
Warning: Permanently added '147.75.33.239' (ECDSA) to the list of known hosts.
ca.pem
kubewrk-2-key.pem
kubewrk-2.pem
Warning: Permanently added '147.75.205.71' (ECDSA) to the list of known hosts.
ca.pem
kubewrk-3-key.pem
kubewrk-3.pem
```

We can check the certificates are present on all the controller servers by running the following Bash snippet:

```
for ip in $(cat /tmp/control_ips.txt);do
  ssh -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no root@$ip \
      ls /etc/kube-certs
done
```

The output will look something like:

```
Warning: Permanently added '147.75.205.51' (ECDSA) to the list of known hosts.
ca-key.pem
ca.pem
kubernetes-key.pem
kubernetes.pem
service-accounts-key.pem
service-accounts.pem
Warning: Permanently added '147.75.83.153' (ECDSA) to the list of known hosts.
ca-key.pem
ca.pem
kubernetes-key.pem
kubernetes.pem
service-accounts-key.pem
service-accounts.pem
Warning: Permanently added '147.75.205.3' (ECDSA) to the list of known hosts.
ca-key.pem
ca.pem
kubernetes-key.pem
kubernetes.pem
service-accounts-key.pem
service-accounts.pem
```

> __Note:__  The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.

Before we move on lets destroy our infrastructure (to save some bucks) by running:

```
terraform destroy
```

Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)

## Sources

* [Kubernete's the Hard Way - 04 Certificate Authority](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md)
* [Packet](https://www.packet.com)
* [Terraform](https://www.terraform.io)
* [Ansible](https://www.ansible.com)
* [Packet CLI](https://github.com/packethost/packet-cli)
* [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)
* [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
* [Packet: Deploy a Server](https://help.packet.net/article/2-deploy-a-server)
* [Packet: Networking FAQ](https://help.packet.net/en-us/article/6-networking-faq)
* [Running a TLS CA with Terraform](https://apparently.me.uk/terraform-certificate-authority/)
* [Terraform: Null Resource](https://www.terraform.io/docs/providers/null/resource.html)
* [Terraform: TLS Provider](https://www.terraform.io/docs/providers/tls/)
