# This is an example of how to use the gke-cluster module to deploy a private Kubernetes cluster in GCP

terraform {
  # The modules used in this example have been updated with 0.12 syntax, additionally we depend on a bug fixed in version 0.12.8
  required_version = ">= 0.12.8"
}

#Providers section

provider "google" {
  credentials = "${file("account.json")}"
  version = "~> 2.9.0"
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

provider "google-beta" {
  credentials = "${file("account.json")}"
  version = "~> 2.9.0"
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# We use this data provider to expose an access token for communicating with the GKE cluster.
data "google_client_config" "client" {}

# Use this datasource to access the Terraform account's email for Kubernetes permissions.
data "google_client_openid_userinfo" "terraform_user" {}

provider "kubernetes" {
  version = "~> 1.7.0"

  load_config_file       = false
  host                   = data.template_file.gke_host_endpoint.rendered
  token                  = data.template_file.access_token.rendered
  cluster_ca_certificate = data.template_file.cluster_ca_certificate.rendered
}

# Deploy private cluster in GCP


module "gke_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.2.0"
  source = "./modules/gke-cluster"

  name = var.cluster_name

  project  = var.project
  location = var.location
  network  = module.vpc_network.network

  # We're deploying the cluster in the 'public' subnetwork to allow outbound internet access
  # See the network access tier table for full details:
  # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
  subnetwork = module.vpc_network.public_subnetwork

  # When creating a private cluster, the 'master_ipv4_cidr_block' has to be defined and the size must be /28
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # This setting will make the cluster private
  enable_private_nodes = "true"

  # To make testing easier, we keep the public endpoint available. In production, we highly recommend restricting access to only within the network boundary, requiring your users to use a bastion host or VPN.
  disable_public_endpoint = "false"

  # With a private cluster, it is highly recommended to restrict access to the cluster master
  # However, for testing purposes we will allow all inbound traffic.
  master_authorized_networks_config = [
    {
      cidr_blocks = [
        {
          cidr_block   = "0.0.0.0/0"
          display_name = "all-for-testing"
        },
      ]
    },
  ]

  cluster_secondary_range_name = module.vpc_network.public_subnetwork_secondary_range_name
}

# Create a node pool


resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  name     = "private-pool"
  project  = var.project
  location = var.location
  cluster  = module.gke_cluster.name

  initial_node_count = "1"

  autoscaling {
    min_node_count = "1"
    max_node_count = "3"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-1"

    labels = {
      private-pools-example = "true"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-pool-example",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}


# CREATE A CUSTOM SERVICE ACCOUNT TO USE WITH THE GKE CLUSTER


module "gke_service_account" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-service-account?ref=v0.2.0"
  source = "./modules/gke-service-account"

  name        = var.cluster_service_account_name
  project     = var.project
  description = var.cluster_service_account_description
}


# CREATE A NETWORK TO DEPLOY THE CLUSTER

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

module "vpc_network" {
  source = "github.com/gruntwork-io/terraform-google-network.git//modules/vpc-network?ref=v0.2.1"

  name_prefix = "${var.cluster_name}-network-${random_string.suffix.result}"
  project     = var.project
  region      = var.region

  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block
}


# CONFIGURE KUBECTL AND RBAC ROLE PERMISSIONS


# configure kubectl with the credentials of the GKE cluster
resource "null_resource" "configure_kubectl" {
  provisioner "local-exec" {
    command = "gcloud beta container clusters get-credentials ${module.gke_cluster.name} --region ${var.region} --project ${var.project}"

    # Use environment variables to allow custom kubectl config paths
    environment = {
      KUBECONFIG = var.kubectl_config_path != "" ? var.kubectl_config_path : ""
    }
  }

  depends_on = [google_container_node_pool.node_pool]
}

# Create a ServiceAccount for Tiller

resource "kubernetes_cluster_role_binding" "user" {
  metadata {
    name = "admin-user"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "User"
    name      = data.google_client_openid_userinfo.terraform_user.email
    api_group = "rbac.authorization.k8s.io"
  }

  # We give the Tiller ServiceAccount cluster admin status so that we can deploy anything in any namespace using this
  # Tiller instance for testing purposes. In production, you might want to use a more restricted role.

  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}


# WORKAROUNDS


# This is a workaround for the Kubernetes and Helm providers as Terraform doesn't currently support passing in module
# outputs to providers directly.
data "template_file" "gke_host_endpoint" {
  template = module.gke_cluster.endpoint
}

data "template_file" "access_token" {
  template = data.google_client_config.client.access_token
}

data "template_file" "cluster_ca_certificate" {
  template = module.gke_cluster.cluster_ca_certificate
}

# DEPLOYMENT

resource "null_resource" "deployment" {
  provisioner "local-exec" {
    command = <<-EOF
        curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
        kubectl create serviceaccount --namespace kube-system tiller
        kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
        kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'      
        helm init --service-account tiller --upgrade
	helm install helloworld/;
    EOF
	}
 depends_on = ["null_resource.configure_kubectl"]
}
