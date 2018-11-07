# Prerequisites

> Note: A list of sources can be found at the end of this post.

## Overview

This post is heavily derived from Kelsey Hightower's Kubernetes the Hard Way but has been changed to use [Packet](https://www.packet.com), [Terraform](https://www.terraform.io) and [Ansible](https://www.ansible.com)

## Packet

This tutorial leverages [Packet](https://www.packet.com) to streamline provisioning of the compute infrastructure required to bootstrap a Kubernetes cluster from the ground up. [Sign up](https://app.packet.net/signup) here.

Packet provides bare metal servers as a service with a nice API to automate provisioning. We will be using spot-priced instances to keep our costs low while following this tutorial.

The estimated cost to run this tutorial: $0.61 per hour ($1.44 per day) (_Am I sure?_).

## Packet CLI

Most of what we will be doing will be via Terraform and Ansible which have built-in APIs but it will be handy to have the Packet CLI around to verify things.

### Install the Packet CLI

Follow the Packet CLI [documentation](https://github.com/packethost/packet-cli) to install and configure the `packet` command line utility.

Verify the Packet CLI version is 0.0.2 or higher:

```bash
packet --version
```

### Setup the CLI

To save typing the API token in we should store the API key. This can be done in `$HOME/.packet-cli.json` (while the documentation states that a YAML file can be used, this does not appear to work):

```json
{
    "token": "PACKET_TOKEN"
}
```

To test:

```bash
packet operating-systems get
```

The result should look something like:

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

### Packet SSH Key

To maintain you Packet servers you will need to configure an SSH key that will be automatically added to the server by the Packet provisioning process.

Assuming you already have a suitable SSH key then run the following:

```
packet ssh-key create -k "$(cat $HOME/.ssh/id_rsa_packet.pub)" -l "My Key"
```

Output:

```
+--------------------------------------+-----------+----------------------+
|                  ID                  |   LABEL   |       CREATED        |
+--------------------------------------+-----------+----------------------+
| be8bc678-c903-4e98-a6bd-bc6dda05a226 | My Key    | 2018-10-17T15:19:08Z |
+--------------------------------------+-----------+----------------------+
```

## Running Commands in Parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with `synchronize-panes` enabled to speed up the provisioning process.

> The use of tmux is optional and not required to complete this tutorial.

![tmux screenshot](images/tmux-screenshot.png)

> Enable `synchronize-panes`: `ctrl+b` then `shift :`. Then type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-ClientTools.md)

## Sources

* [Kubernete's the Hard Way - 01 Prerequisites](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md)
* [Packet](https://www.packet.com)
* [Terraform](https://www.terraform.io)
* [Ansible](https://www.ansible.com)
* [Packet CLI](https://github.com/packethost/packet-cli)