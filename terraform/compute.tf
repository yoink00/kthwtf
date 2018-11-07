provider "packet" {}

data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "./global/terraform.tfstate"
  }
}

# Kubernetes Controllers
resource "packet_device" "kube_control" {
  hostname         = "kubectl-${count.index + 1}"
  plan             = "baremetal_0"
  facility         = "ams1"
  operating_system = "ubuntu_18_04"
  billing_cycle    = "hourly"
  project_id       = "${data.terraform_remote_state.global.project_id}"
  count            = "${var.kube_control_count}"
}

# Kubernetes Workers
resource "packet_device" "kube_worker" {
  hostname         = "kubewrk-${count.index + 1}"
  plan             = "baremetal_0"
  facility         = "ams1"
  operating_system = "ubuntu_18_04"
  billing_cycle    = "hourly"
  project_id       = "${data.terraform_remote_state.global.project_id}"
  tags             = ["pod-cidr=192.168.${count.index + 1}.0/24"]
  count            = "${var.kube_worker_count}"
}

