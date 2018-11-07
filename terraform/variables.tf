variable "kube_control_count" {
  default = 3
}

variable "kube_worker_count" {
  default = 3
}

variable "kube_key_uses" {
  default = ["cert_signing", "client_auth", "server_auth", "key_encipherment"]
}

