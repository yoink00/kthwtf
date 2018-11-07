provider "packet" {}

resource "packet_project" "kthwtf" {
  name           = "Kubernetes the Hard Way with Terraform"
}

output "project_id" {
  value = "${packet_project.kthwtf.id}"
}
