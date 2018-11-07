# Installing the Client Tools

> Note: A list of sources can be found at the end of this post.

## Overview

This post is heavily derived from Kelsey Hightower's Kubernetes the Hard Way but has been changed to use [Packet](https://www.packet.com), [Terraform](https://www.terraform.io) and [Ansible](https://www.ansible.com)

In this lab you will install the command line utilities required to complete this tutorial: [cfssl](https://github.com/cloudflare/cfssl), [cfssljson](https://github.com/cloudflare/cfssl), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl), [Terraform](https://www.terraform.io/intro/getting-started/install.html) and [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)


## Install CFSSL

The `cfssl` and `cfssljson` command line utilities will be used to provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) and generate TLS certificates.

Download and install `cfssl` and `cfssljson` from the [cfssl repository](https://pkg.cfssl.org):


### Linux

```
curl -o cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
```

```
chmod +x cfssl cfssljson
```

```
mv cfssl cfssljson $HOME/.local/bin
```
> Note: I place all my downloaded binaries in `$HOME/.local/bin`. You may wish to place them in `/usr/local/bin` instead.

### Verification

Verify `cfssl` version 1.2.0 or higher is installed:

```
cfssl version
```

Output:

```
Version: 1.2.0
Revision: dev
Runtime: go1.6
```

> Note: The cfssljson command line utility does not provide a way to print its version.

## Install kubectl

The `kubectl` command line utility is used to interact with the Kubernetes API Server. Download and install `kubectl` from the official release binaries:

### Linux

```
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/linux/amd64/kubectl
```

```
chmod +x kubectl
```

```
mv kubectl $HOME/.local/bin
```

### Verification

Verify `kubectl` version 1.12.0 or higher is installed:

```
kubectl version --client
```

Output:

```
Client Version: version.Info{Major:"1", Minor:"12", GitVersion:"v1.12.0", GitCommit:"0ed33881dc4355495f623c6f22e7dd0b7632b7c0", GitTreeState:"clean", BuildDate:"2018-09-27T17:05:32Z", GoVersion:"go1.10.4", Compiler:"gc", Platform:"linux/amd64"}
```

## Install Terraform

We are using the `terraform` command line utility to manage the Packet infrastructure our Kubernetes cluster is running on. Download and install `terraform` from the official release binaries:

### Linux

```
curl -O https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
```

```
unzip terraform_0.11.8_linux_amd64.zip
```

```
mv terraform $HOME/.local/bin
```

```
rm terraform_0.11.8_linux_amd64.zip
```

### Verification

Verify `terraform` version 0.11.8 or higher is installed:

```
terraform version
```

Output:

```
Terraform v0.11.8
```

## Install Ansible

We will be using the `ansible-pull` command on the servers themselves to pull down their configuration. It maybe useful to have the Ansible commands available locally for testing.

### Linux (Fedora 28)

```
sudo dnf install -y ansible
```

### Verification

Verify `ansible` version 2.6.5 or highter is installed:

```
ansible --version
```
Output:
```
ansible 2.6.5
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/user/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.15 (default, Sep 21 2018, 23:26:48) [GCC 8.1.1 20180712 (Red Hat 8.1.1-5)]
```

## Install Git

We will be keeping the configuration of our servers in Git so we will need the `git` command-line tool.

### Linux (Fedora 28)

```
sudo dnf install -y git
```

### Verification

```
git version
```

Output:

```
git version 2.17.1
```

## Initialising

As we are using Ansible, Terraform and Git there is a bit of initialisation to do:

### Git Repo

We will be using Git to keep our Ansible configuration. I'll also be putting my Terraform configuration in here too but you don't have to; this will work without doing that.

This assumes you have a [Github](https://github.com) account and you've set up a repo to keep all your code. Any Git repo/provider will work just tweak the instructions below to compensate.

```
git init kthwtf
```

```
cd kthwtf
git remote add origin git@github.com:your_git_repo/kthwtf.git
git fetch
git checkout master
```

### Terraform

Assuming you're still in the `kthwtf` directory

```
mkdir terraform
cd terraform
```

Edit `packet.tf` in your favourite text editor and add the following:

```hcl
provider "packet" {
}
```

To keep things DRY I add a small helper script called `tf` with the following content:

```bash
#!/bin/sh

packet_token=$(grep token $HOME/.packet-cli.json | sed 's/^\s*"token"\s*:\s*"\([^"]*\)".*$/\1/g')

export PACKET_AUTH_TOKEN=$packet_token

terraform $*

```

This will call `terraform` with the same token that is used by the Packet CLI.

Run:

```
chmod +x tf
./tf init
```

You should see output that looks like:

```

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "packet" (1.2.5)...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.packet: version = "~> 1.2"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

This will have installed the Packet Terraform provider.

Run:

```
./tf plan
```

The output should be:

```
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

No changes. Infrastructure is up-to-date.

This means that Terraform did not detect any differences between your
configuration and real physical resources that exist. As a result, no
actions need to be performed.
```

> Note: The rest of the tutorials will use `terraform` instead of `./tf` but you can substitute `./tf` to use the CLI token.

Next: [Provisioning Compute Resources](03-ComputeResources.md)

## Sources

* [Kubernete's the Hard Way - 02 Client Tools](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-client-tools.md)
* [Packet](https://www.packet.com)
* [Terraform](https://www.terraform.io)
* [Ansible](https://www.ansible.com)
* [Packet CLI](https://github.com/packethost/packet-cli)
* [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)
* [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
