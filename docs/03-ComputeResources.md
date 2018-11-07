# Provisioning Compute Resources

> Note: A list of sources can be found at the end of this post.

## Overview

This post is heavily derived from Kelsey Hightower's Kubernetes the Hard Way but has been changed to use [Packet](https://www.packet.com), [Terraform](https://www.terraform.io) and [Ansible](https://www.ansible.com)

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers are ultimately run. In this lab you will provision the compute resources required for running a secure and highly available Kubernetes cluster across a single Packet datacentre

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other. In cases where this is not desired [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) can limit how groups of containers are allowed to communicate with each other and external network endpoints.

> Setting up network policies is out of scope for this tutorial.

### Packet Project

A Packet project allows you to organize groups of servers, collaborators and to support backend networking. When you create a new project, the platform assigns two IP blocks: a per-facility /56 IPv6 and /25 Private IPv4.

When you then deploy servers into a project, each machine gets 1 Public IPv4 from Packet’s general pool, as well as 1 Private IPv4 and 1 IPv6 from the blocks already assigned to the project.

Note: The Public IPv4 is intended for server maintenance and you will lose this IPv4 when you delete the server.

We are going to create a new Packet project.

In `compute.tf` add the following block:

```hcl
resource "packet_project" "kthwtf" {
  name           = "Kubernetes the Hard Way with Terraform"
}
```

Save it and run:

```
terraform plan
```

This will show you the changes that will be made to your infrastructure. The output should look like:

```
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + packet_project.kthwtf
      id:      <computed>
      created: <computed>
      name:    "Kubernetes the Hard Way with Terraform"
      updated: <computed>


Plan: 1 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

This output shows us that we will be adding a Packet project resource to our infrastructure.

Run:

```
terraform apply
```

Output:

```

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + packet_project.kthwtf
      id:      <computed>
      created: <computed>
      name:    "Kubernetes the Hard Way with Terraform"
      updated: <computed>


Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

packet_project.kthwtf: Creating...
  created: "" => "<computed>"
  name:    "" => "Kubernetes the Hard Way with Terraform"
  updated: "" => "<computed>"
packet_project.kthwtf: Creation complete after 1s (ID: 4ab0fafa-ae8b-4fa5-849f-e89466431310)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Verify:

```
packet project get
```

Output:

```
+--------------------------------------+----------------------------------------+----------------------+
|                  ID                  |                  NAME                  |       CREATED        |
+--------------------------------------+----------------------------------------+----------------------+
| 4ab0fafa-ae8b-4fa5-849f-e89466431310 | Kubernetes the Hard Way with Terraform | 2018-10-17T15:33:25Z |
+--------------------------------------+----------------------------------------+----------------------+
```

## Variables

Along the way we are going to need a few variables that will be shared across a number of different resources. Create a `variables.tf` file and add the following to it:

```
variable "kube_control_count" {
  default = 3
}

variable "kube_worker_count" {
  default = 3
}
```

These variables define the number of controllers (`kube_control_count`) and the number of workers (`kube_worker_count`) we will be deploying. These will be refered to as we deploy instances below.

## Compute Instances

The compute instances in this lab will be provisioned using [Ubuntu Server](https://www.ubuntu.com/server) 18.04, which has good support for the [containerd container runtime](https://github.com/containerd/containerd).

### Kubernetes Controllers

Create three compute instances which will host the Kubernetes control plane. To do this add the following block to `compute.tf`:

```
# Kubernetes Controllers
resource "packet_device" "kube_control" {
  hostname         = "kubectl-${count.index + 1}"
  plan             = "baremetal_1"
  facility         = "ams1"
  operating_system = "ubuntu_18_04"
  billing_cycle    = "hourly"
  project_id       = "${packet_project.kthwtf.id}"
  count            = "${var.kube_control_count}"
}
```

This block will create three hosts (see `count`) with names `kubectl_1`, `kubectl_2` and `kubectl_3` all in the Amsterdam facility running Ubuntu 18.04 running on the small Atom powered server.

You can get the values for these parameters using the Packet CLI:

```
packet operating-systems get
```

Output:

```
+---------------------------+--------------------+-------------+------------+
|           NAME            |        SLUG        |   DISTRO    |  VERSION   |
+---------------------------+--------------------+-------------+------------+
| Alpine 3                  | alpine_3           | alpine      | 3          |
| CentOS 6                  | centos_6           | centos      | 6          |
| CentOS 7                  | centos_7           | centos      | 7          |
| Container Linux - Alpha   | coreos_alpha       | coreos      | alpha      |
| Container Linux - Beta    | coreos_beta        | coreos      | beta       |
| Container Linux - Stable  | coreos_stable      | coreos      | stable     |
| Custom iPXE               | custom_ipxe        | custom_ipxe | 1          |
| Debian 8                  | debian_8           | debian      | 8          |
| Debian 9                  | debian_9           | debian      | 9          |
| Deprovision               | deprovision        | centos      |            |
| FreeBSD 10.3              | freebsd_10_3       | freebsd     | 10.3       |
| FreeBSD 10.4              | freebsd_10_4       | freebsd     | 10.4       |
| FreeBSD 11.0              | freebsd_11_0       | freebsd     | 11.0       |
| FreeBSD 11.1              | freebsd_11_1       | freebsd     | 11.1       |
| FreeBSD 12-testing        | freebsd_12_testing | freebsd     | 12-testing |
| NixOS 18.03               | nixos_18_03        | nixos       | 18.03      |
| OpenSUSE 42.3             | opensuse_42_3      | opensuse    | 42.3       |
| RancherOS                 | rancher            | rancher     | latest     |
| RedHat Enterprise Linux 7 | rhel_7             | rhel        | 7          |
| Scientific Linux 6        | scientific_6       | scientific  | 6          |
| SLES 12 SP3               | suse_sles12_sp3    | suse        | 12 SP3     |
| Ubuntu 14.04 LTS          | ubuntu_14_04       | ubuntu      | 14.04      |
| Ubuntu 16.04 LTS          | ubuntu_16_04       | ubuntu      | 16.04      |
| Ubuntu 17.10              | ubuntu_17_10       | ubuntu      | 17.10      |
| Ubuntu 18.04 LTS          | ubuntu_18_04       | ubuntu      | 18.04      |
| VMware ESXi 6.5           | vmware_esxi_6_5    | vmware      | 6.5        |
| Windows 2012 R2           | windows_2012_r2    | windows     | 2012 R2    |
| Windows 2016 Standard     | windows_2016       | windows     | 2016       |
+---------------------------+--------------------+-------------+------------+

```
```
packet facilities get
```

Output:

```
+-------------------+------+--------------------------------------------------------+
|       NAME        | CODE |                        FEATURES                        |
+-------------------+------+--------------------------------------------------------+
| Toronto, ON, CA   | yyz1 | baremetal,layer_2                                      |
| Tokyo, JP         | nrt1 | baremetal,layer_2,storage,global_ipv4,backend_transfer |
| Atlanta, GA       | atl1 | baremetal,layer_2,backend_transfer                     |
| Marseille, France | mrs1 | baremetal,layer_2,backend_transfer                     |
| Hong Kong 1, HK   | hkg1 | baremetal,layer_2,backend_transfer                     |
| Amsterdam, NL     | ams1 | baremetal,storage,global_ipv4,backend_transfer,layer_2 |
| Parsippany, NJ    | ewr1 | baremetal,storage,backend_transfer,layer_2,global_ipv4 |
| Singapore         | sin1 | baremetal,layer_2                                      |
| Dallas, TX        | dfw1 | baremetal,layer_2,backend_transfer                     |
| Los Angeles, CA   | lax1 | baremetal,layer_2,backend_transfer                     |
| Sydney, Australia | syd1 | baremetal,layer_2                                      |
| Sunnyvale, CA     | sjc1 | baremetal,storage,layer_2,global_ipv4,backend_transfer |
| Chicago, IL       | ord1 | baremetal,layer_2,backend_transfer                     |
| Ashburn, VA       | iad1 | baremetal,layer_2,backend_transfer                     |
| Frankfurt, DE     | fra1 | baremetal,layer_2,backend_transfer                     |
| Seattle, WA       | sea1 | baremetal,layer_2,backend_transfer                     |
+-------------------+------+--------------------------------------------------------+
```

```
packet plan get
```

Output:

```
+--------------------------------------+---------------+---------------+
|                  ID                  |     SLUG      |     NAME      |
+--------------------------------------+---------------+---------------+
| 5aeee4f9-1137-4514-8f3e-a1e103b02966 | c2.medium.x86 | c2.medium.x86 |
| c5a9c64a-07e4-46a9-8dfe-2437f521dcb8 | m2.xlarge.x86 | m2.xlarge.x86 |
| 87728148-3155-4992-a730-8d1e6aca8a32 | storage_1     | Standard      |
| d6570cfb-38fa-4467-92b3-e45d059bb249 | storage_2     | Performance   |
| 3bc8a214-b807-4058-ad4a-6925f2411155 | baremetal_2a  | c1.large.arm  |
| 6d1f1ffa-7912-4b78-b50d-88cc7c8ab40f | baremetal_1   | c1.small.x86  |
| 741f3afb-bb2f-4694-93a0-fcbad7cd5e78 | baremetal_3   | c1.xlarge.x86 |
| a3729923-fdc4-4e85-a972-aafbad3695db | baremetal_2   | m1.xlarge.x86 |
| 66173669-84fc-43b3-92b5-64f84497c887 | baremetal_s   | s1.large.x86  |
| e69c0169-4726-46ea-98f1-939c9e8a3607 | baremetal_0   | t1.small.x86  |
| e829e15f-bfa0-4d8f-806e-cc92bb6567b4 | baremetal_1e  | x1.small.x86  |
+--------------------------------------+---------------+---------------+
```

Run:

```
terraform plan
```

Output:

```
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

packet_project.kthwtf: Refreshing state... (ID: 4ab0fafa-ae8b-4fa5-849f-e89466431310)

------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + packet_device.kube_control[0]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl_1"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>

  + packet_device.kube_control[1]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl_2"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>

  + packet_device.kube_control[2]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl_3"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>


Plan: 3 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

### Kubernetes Workers

Each worker instance a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking in a later exercise. The `pod-cidr` instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

> The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this series the cluster CIDR range will be set to `192.168.0.0/16`, which supports 256 subnets.

Create three compute instances which will host the Kubernetes worker nodes:

```
# Kubernetes Workers
resource "packet_device" "kube_worker" {
  hostname         = "kubewrk-${count.index + 1}"
  plan             = "baremetal_1"
  facility         = "ams1"
  operating_system = "ubuntu_18_04"
  billing_cycle    = "hourly"
  project_id       = "${packet_project.kthwtf.id}"
  tags             = ["pod-cidr=192.168.${count.index + 1}.0/24"]
  count            = "${var.kube_worker_count}"
}
```

### Apply the Terraform Config

```
terraform apply
```

It will take about 6 minutes for this deployment.

Output (abbreviated):

```
packet_project.kthwtf: Refreshing state... (ID: 4ab0fafa-ae8b-4fa5-849f-e89466431310)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + packet_device.kube_control[0]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl-1"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>

  + packet_device.kube_control[1]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl-2"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>

  + packet_device.kube_control[2]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubectl-3"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      updated:                 <computed>

  + packet_device.kube_worker[0]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubewrk-1"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      tags.#:                  "1"
      tags.0:                  "pod-cidr=192.168.1.0/24"
      updated:                 <computed>

  + packet_device.kube_worker[1]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubewrk-2"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      tags.#:                  "1"
      tags.0:                  "pod-cidr=192.168.2.0/24"
      updated:                 <computed>

  + packet_device.kube_worker[2]
      id:                      <computed>
      access_private_ipv4:     <computed>
      access_public_ipv4:      <computed>
      access_public_ipv6:      <computed>
      always_pxe:              "false"
      billing_cycle:           "hourly"
      created:                 <computed>
      facility:                "ams1"
      hardware_reservation_id: <computed>
      hostname:                "kubewrk-3"
      locked:                  <computed>
      network.#:               <computed>
      operating_system:        "ubuntu_18_04"
      plan:                    "baremetal_1"
      project_id:              "4ab0fafa-ae8b-4fa5-849f-e89466431310"
      public_ipv4_subnet_size: <computed>
      root_password:           <computed>
      state:                   <computed>
      tags.#:                  "1"
      tags.0:                  "pod-cidr=192.168.3.0/24"
      updated:                 <computed>


Plan: 6 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.3.0/24"
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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.1.0/24"
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
  plan:                    "" => "baremetal_1"
  project_id:              "" => "4ab0fafa-ae8b-4fa5-849f-e89466431310"
  public_ipv4_subnet_size: "" => "<computed>"
  root_password:           "<sensitive>" => "<sensitive>"
  state:                   "" => "<computed>"
  tags.#:                  "" => "1"
  tags.0:                  "" => "pod-cidr=192.168.2.0/24"
  updated:                 "" => "<computed>"
packet_device.kube_control.2: Still creating... (10s elapsed)
...
...
packet_device.kube_worker[1]: Creation complete after 5m7s (ID: f8cd8c57-161a-42d7-8ff5-8c90eb8d2875)
packet_device.kube_control[1]: Creation complete after 5m7s (ID: b3139826-43ae-4e92-b5b5-aac163270356)
...
...
packet_device.kube_worker[2]: Creation complete after 5m40s (ID: 6428953f-b0dd-4f8e-bdd4-649a7cd466d6)
packet_device.kube_control[0]: Creation complete after 5m41s (ID: eb06147e-e9ab-4474-b4fd-97985e18dd90)
...
...
packet_device.kube_worker[0]: Creation complete after 6m23s (ID: 36569109-ad14-4f6f-8e98-d39116e87c51)
packet_device.kube_control[2]: Creation complete after 6m23s (ID: c3dafbba-869b-4fce-ac7e-cb4ae76f877b)
```

### Verification

List the compute instances in your project:

```
packet device get -p 4ab0fafa-ae8b-4fa5-849f-e89466431310
```

Output:

```
+--------------------------------------+-----------+------------------+--------+----------------------+
|                  ID                  | HOSTNAME  |        OS        | STATE  |       CREATED        |
+--------------------------------------+-----------+------------------+--------+----------------------+
| 36569109-ad14-4f6f-8e98-d39116e87c51 | kubewrk-1 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:34Z |
| c3dafbba-869b-4fce-ac7e-cb4ae76f877b | kubectl-3 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:35Z |
| eb06147e-e9ab-4474-b4fd-97985e18dd90 | kubectl-1 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:34Z |
| 6428953f-b0dd-4f8e-bdd4-649a7cd466d6 | kubewrk-3 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:34Z |
| b3139826-43ae-4e92-b5b5-aac163270356 | kubectl-2 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:34Z |
| f8cd8c57-161a-42d7-8ff5-8c90eb8d2875 | kubewrk-2 | Ubuntu 18.04 LTS | active | 2018-10-17T20:47:34Z |
+--------------------------------------+-----------+------------------+--------+----------------------+
```

### Test SSH Access

Get the IP address of one of our servers:

```
packet device get -p 4ab0fafa-ae8b-4fa5-849f-e89466431310 -y | less
```

Output (abbreviated. We are looking for a public IP address):

```
- billing_cycle: hourly
  created_at: "2018-10-17T20:47:34Z"
  facility:
    address: {}
    code: ams1
    features:
    - baremetal
    - storage
    - global_ipv4
    - backend_transfer
    - layer_2
    id: 8e6470b3-b75e-47d1-bb93-45b225750975
    name: Amsterdam, NL
  hardware_reservation:
    href: ""
  hostname: kubewrk-1
  href: /devices/36569109-ad14-4f6f-8e98-d39116e87c51
  id: 36569109-ad14-4f6f-8e98-d39116e87c51
  ip_addresses:
  - address: 147.75.80.177
    address_family: 4
    assigned_to:
      href: /devices/36569109-ad14-4f6f-8e98-d39116e87c51
    cidr: 31
    created_at: "2018-10-17T20:47:38Z"
    gateway: 147.75.80.176
    href: /ips/5ba322b1-e30e-4197-b370-72f69ac29586
    id: 5ba322b1-e30e-4197-b370-72f69ac29586
    manageable: true
    management: true
    netmask: 255.255.255.254
    ...
    ...
    ...
```

```
ssh root@147.75.80.177
```

Output:

```
ssh root@147.75.80.177
The authenticity of host '147.75.80.177 (147.75.80.177)' can't be established.
ECDSA key fingerprint is SHA256:cCcpm2UBMC1+Vb+CNy/A/CdwdiKnOzCflxPDLLKcCtk.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '147.75.80.177' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04 LTS (GNU/Linux 4.15.0-20-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

 * Security certifications for Ubuntu!
   We now have FIPS, STIG, CC and a CIS Benchmark.

   - http://bit.ly/Security_Certification

 * Want to make a highly secure kiosk, smart display or touchscreen?
   Here's a step-by-step tutorial for a rainy weekend, or a startup.

   - https://bit.ly/secure-kiosk


The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.
```

Before moving on run:

```
terrafrom destroy
```

This will destroy all the infrastructure we've deployed thus far (and saving some bucks) 'til we're ready to continue.

The output should look like:

```
packet_project.kthwtf: Refreshing state... (ID: 098a744b-cea9-486c-846c-f6be44980233)
packet_device.kube_control[2]: Refreshing state... (ID: 352bce9f-9e24-40a8-8768-ab39af885123)
packet_device.kube_worker[0]: Refreshing state... (ID: f312daca-a7f9-4e8b-b025-d6898b047df2)
packet_device.kube_control[0]: Refreshing state... (ID: ed724967-1318-4e1a-b386-736341f67b7e)
packet_device.kube_control[1]: Refreshing state... (ID: 8243ddab-343f-4fba-bd57-d53bdbf57e38)
packet_device.kube_worker[1]: Refreshing state... (ID: b350ac88-4370-45d0-ad16-f6c6641163eb)
packet_device.kube_worker[2]: Refreshing state... (ID: 5ab4bf8b-468d-44f7-a2c0-c6ef3e73cd38)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  - packet_device.kube_control[0]

  - packet_device.kube_control[1]

  - packet_device.kube_control[2]

  - packet_device.kube_worker[0]

  - packet_device.kube_worker[1]

  - packet_device.kube_worker[2]

  - packet_project.kthwtf

Plan: 0 to add, 0 to change, 7 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

packet_device.kube_worker[1]: Destruction complete after 1s
packet_device.kube_worker[0]: Destruction complete after 2s
packet_device.kube_control[2]: Destruction complete after 2s
packet_device.kube_worker[2]: Destruction complete after 2s
packet_device.kube_control[1]: Destruction complete after 2s
packet_device.kube_control[0]: Destruction complete after 2s
packet_project.kthwtf: Destroying... (ID: 098a744b-cea9-486c-846c-f6be44980233)
packet_project.kthwtf: Destruction complete after 5s

Destroy complete! Resources: 7 destroyed.
```

Next: [Provisioning a CA and Generating TLS Certificates](04-CertificateAuthority.md)

## Sources

* [Kubernete's the Hard Way - 03 Compute Resources](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md)
* [Packet](https://www.packet.com)
* [Terraform](https://www.terraform.io)
* [Ansible](https://www.ansible.com)
* [Packet CLI](https://github.com/packethost/packet-cli)
* [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)
* [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
* [Packet: Deploy a Server](https://help.packet.net/article/2-deploy-a-server)
* [Packet: Networking FAQ](https://help.packet.net/en-us/article/6-networking-faq)