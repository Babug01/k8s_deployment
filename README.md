# Google Kubernetes Engine (GKE) Module with Helm

This repo contains a [Terraform](https://www.terraform.io) module for running a Kubernetes cluster on [Google Cloud Platform (GCP)](https://cloud.google.com/)
using [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/).

## Quickstart

If you want to quickly spin up a GKE Private Cluster with Tiller, you can run the example that is in the root of this
repo. Check out the [gke-private-tiller example documentation](https://github.com/gruntwork-io/terraform-google-gke/blob/master/examples/gke-private-tiller)
for instructions.

## What's in this repo

This repo has the following folder structure:

* [modules](https://github.com/gruntwork-io/terraform-google-gke/tree/master/modules): This folder contains the
  main implementation code for this Module, broken down into multiple standalone submodules.

  The primary module is:

    * [gke-cluster](https://github.com/Babug01/k8s_deployment/tree/master/modules/gke-cluster): The GKE Cluster module is used to
    administer the [cluster master](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture)
    for a [GKE Cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-admin-overview).

    There are also several supporting modules that add extra functionality on top of `gke-cluster`:

    * [gke-service-account](https://github.com/Babug01/k8s_deployment/tree/master/modules/gke-service-account):
    Used to configure a GCP service account for use with a GKE cluster.

	* [helloworld] (https://github.com/Babug01/k8s_deployment/tree/master/helloworld): This is the application we are deploying into the cluster using Helm.
	
## What is Kubernetes?

[Kubernetes](https://kubernetes.io) is an open source container management system for deploying, scaling, and managing
containerized applications. Kubernetes is built by Google based on their internal proprietary container management
systems (Borg and Omega). Kubernetes provides a cloud agnostic platform to deploy your containerized applications with
built in support for common operational tasks such as replication, autoscaling, self-healing, and rolling deployments.

You can learn more about Kubernetes from [the official documentation](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

## What is GKE?

Google Kubernetes Engine or "GKE" is a Google-managed Kubernetes environment. GKE is a fully managed experience; it
handles the management/upgrading of the Kubernetes cluster master as well as autoscaling of "nodes" through "node pool"
templates.

Through GKE, your Kubernetes deployments will have first-class support for GCP IAM identities, built-in configuration of
high-availability and secured clusters, as well as native access to GCP's networking features such as load balancers.

## <a name="how-to-run-applications"></a>How do you run applications on Kubernetes?

There are three different ways you can schedule your application on a Kubernetes cluster. In all three, your application
Docker containers are packaged as a [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod/), which are the
smallest deployable unit in Kubernetes, and represent one or more Docker containers that are tightly coupled. Containers
in a Pod share certain elements of the kernel space that are traditionally isolated between containers, such as the
network space (the containers both share an IP and thus the available ports are shared), IPC namespace, and PIDs in some
cases.

Pods are considered to be relatively ephemeral disposable entities in the Kubernetes ecosystem. This is because Pods are
designed to be mobile across the cluster so that you can design a scalable fault tolerant system. As such, Pods are
generally scheduled with
[Controllers](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/#pods-and-controllers) that manage the
lifecycle of a Pod. Using Controllers, you can schedule your Pods as:

- Jobs, which are Pods with a controller that will guarantee the Pods run to completion.
- Deployments behind a Service, which are Pods with a controller that implement lifecycle rules to provide replication
  and self-healing capabilities. Deployments will automatically reprovision failed Pods, or migrate Pods to healthy
  nodes off of failed nodes. A Service constructs a consistent endpoint that can be used to access the Deployment.
- Daemon Sets, which are Pods that are scheduled on all worker nodes. Daemon Sets schedule exactly one instance of a Pod
  on each node. Like Deployments, Daemon Sets will reprovision failed Pods and schedule new ones automatically on
  new nodes that join the cluster.

<!-- TODO: ## What parts of the Production Grade Infrastructure Checklist are covered by this Module? -->

## What's a Module?

A Module is a canonical, reusable, best-practices definition for how to run a single piece of infrastructure, such
as a database or server cluster. Each Module is written using a combination of [Terraform](https://www.terraform.io/)
and scripts (mostly bash) and include automated tests, documentation, and examples. It is maintained both by the open
source community and companies that provide commercial support.

Instead of figuring out the details of how to run a piece of infrastructure from scratch, you can reuse
existing code that has been proven in production. And instead of maintaining all that infrastructure code yourself,
you can leverage the work of the Module community to pick up infrastructure improvements through
a version number bump.

## Contents:
	- Architecture Diagram
	- Prerequistes
	- Installation of terraform, Helm and kubergrunt
	- Jenkins setup
	- Application (Helloworld)
	- Logs Monitor
	
	
## Architecture Diagram

![Alt text][https://github.com/Babug01/k8s_deployment/blob/master/architecture/architect.png]

## Prerequistes

- GCP Account
- Jenkins
- Terraform
- Helm

## Installation

# Terraform

$ wget -q https://releases.hashicorp.com/terraform/0.11.6/terraform_0.11.6_linux_amd64.zip

$ unzip terraform_0.12.8_linux_amd64.zip
Archive:  terraform_0.12.8_linux_amd64.zip
  inflating: terraform               

$ sudo mv terraform /usr/local/bin/terraform

$ terraform version
Terraform v0.12.8

# Helm and Kubergrunt

kubergrunt is a standalone go binary with a collection of commands that attempts to fill in the gaps between Terraform, Helm, and Kubectl for managing a Kubernetes Cluster.

Some of the features of kubergrunt include:

- Configuring kubectl to authenticate with a given EKS cluster. Learn more about authenticating kubectl to EKS in the our production deployment guide.
- Managing Helm and associated TLS certificates on any Kubernetes cluster.
- Setting up Helm client with TLS certificates on any Kubernetes cluster.
- Generating TLS certificate key pairs and storing them as Kubernets Secrets on any Kubernetes cluster.

$ gruntwork-install --binary-name "kubergrunt" --repo "https://github.com/gruntwork-io/kubergrunt" --tag "v0.5.8"
[https://github.com/gruntwork-io/kubergrunt]

