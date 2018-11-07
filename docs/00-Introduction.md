# Introduction

## Overview

This is the beginning of a series of blog posts exploring modern microservices architecture, development and deployment. The series is on-going and wll be updated as new technoglies are explored.

The end goal is a fully functioning containerised microservices application of some form (to be decided :-) ) running in container orchestration.

The main deliverable from this is learning. We aim to find out how all the tools we use fit together and how we can use them to build and deploy our solution.

We need somewhere to start and we are going to start by installing Kubernetes from scratch. We are also going to use [Terraform](https://www.terraform.io) to manage our infrastructure and [Ansible](https://www.ansible.com) to configure our servers though we are going to treat our servers as immutable once the initial Terraform and the initial Ansible playbook has run.

The main source of information for the installation of Kubernetes is Kelsey Hightower's excellent [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

To make things a bit trickier we are going to use [Packet](http://www.packet.com) as our host.