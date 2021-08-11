/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

## GKE Safer Cluster

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  cluster_type       = "safer-cluster"
  network_project_id = data.google_project.network_project.project_id
  network_name       = data.google_compute_network.shared_vpc.name
  subnet_name        = data.google_compute_subnetwork.subnetwork.name
  pods_range_name    = "rn-${local.environment_code}-shared-${var.vpc_type}-${var.region}-gke-pod"
  svc_range_name     = "rn-${local.environment_code}-shared-${var.vpc_type}-${var.region}-gke-svc"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  version                = "2.3.2"
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

data "google_project" "gke_project" {
  project_id = data.google_project.env_project.project_id
}

module "gke" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  project_id                      = data.google_project.env_project.project_id
  name                            = "boa-1-cluster-${random_string.suffix.result}"
  region                          = var.region
  zones                           = ["${var.region}-a"]
  network_project_id              = local.network_project_id
  network                         = local.network_name
  subnetwork                      = local.subnet_name
  ip_range_pods                   = local.pods_range_name
  ip_range_services               = local.svc_range_name
  initial_node_count              = 0
  http_load_balancing             = true
  enable_vertical_pod_autoscaling = true
  authenticator_security_group    = "gke-security-groups@bankon.cloud"
  master_authorized_networks = [{
    cidr_block   = "10.0.64.0/32"
    display_name = "sb-${local.environment_code}-shared-${var.vpc_type}-${var.region}"
  }] # Master authorized networks must be enabled if private endpoint is enabled.

  cluster_resource_labels = {
    "mesh_id" = "proj-${data.google_project.gke_project.number}"
  }

  node_pools_tags = {
    "np-${var.region}" : ["allow-google-apis", "egress-internet", "allow-lb"]
  }
  node_pools = [
    {
      name                        = "np-${var.region}"
      auto_repair                 = true
      auto_upgrade                = true
      enable_secure_boot          = true
      enable_shielded_nodes       = true
      enable_integrity_monitoring = true
      image_type                  = "COS_CONTAINERD"
      machine_type                = "e2-standard-2"
      min_count                   = 0
      max_count                   = 3
      node_metadata               = "GKE_METADATA_SERVER"
    }
  ]
  node_pools_oauth_scopes = {
    "all" : [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ],
    "default-node-pool" : []
  }

  notification_config_topic = google_pubsub_topic.updates.id
}

resource "google_pubsub_topic" "updates" {
  name    = "cluster-updates-${random_string.suffix.result}"
  project = data.google_project.env_project.project_id
}






# # Add IAM to roles/container.clusterViewer
# resource "google_project_iam_policy" "boa_gke_cluster_viewer" {
#   project     = data.google_project.env_project.project_id
#   policy_data = data.google_iam_policy.boa_gke_cluster_viewer.policy_data
# }

# data "google_iam_policy" "boa_gke_cluster_viewer" {
#   binding {
#     role = "roles/container.clusterViewer"

#     members = [
#       "serviceAccount:sa-example-app@prj-bu2-d-sample-base-aed2.iam.gserviceaccount.com",
#     ]
#   }
# }




# ## Creates VPC network
# resource "google_compute_network" "vpc_network" {
#   project                 = "prj-bu2-d-sample-base-aed2" #data.google_project.env_project.project_id
#   name                    = "bank-of-anthos"
#   auto_create_subnetworks = "false"
# }

# resource "google_compute_subnetwork" "vpc_subnet_01" {
#   project       = "prj-bu2-d-sample-base-aed2" #data.google_project.env_project.project_id
#   name          = "asia-southeast1-01"
#   ip_cidr_range = "10.148.0.0/20"
#   region        = "asia-southeast1"
#   network       = google_compute_network.vpc_network.self_link

#   secondary_ip_range {
#     range_name    = "asia-southeast1-01-gke-pods"
#     ip_cidr_range = "192.168.0.0/20"
#   }
#   secondary_ip_range {
#     range_name    = "asia-southeast1-01-gke-services"
#     ip_cidr_range = "192.168.16.0/20"
#   }
# }


# # # GKE
# # # google_client_config and kubernetes provider must be explicitly specified like the following.
# # data "google_client_config" "default" {}

# # provider "kubernetes" {
# #   version                = "2.3.2"
# #   host                   = "https://${module.gke.endpoint}"
# #   token                  = data.google_client_config.default.access_token
# #   cluster_ca_certificate = base64decode(module.gke.ca_certificate)
# # }

# # module "gke" {
# #   source                     = "terraform-google-modules/kubernetes-engine/google"
# #   project_id                 = "prj-bu2-d-sample-base-aed2" #data.google_project.env_project.project_id
# #   name                       = "bank-of-anthos-deployment"
# #   region                     = var.instance_region
# #   zones                      = ["${var.instance_region}-a"]
# #   network                    = google_compute_network.vpc_network.name
# #   subnetwork                 = google_compute_subnetwork.vpc_subnet_01.name
# #   ip_range_pods              = "${var.instance_region}-01-gke-pods"
# #   ip_range_services          = "${var.instance_region}-01-gke-services"
# #   http_load_balancing        = false
# #   horizontal_pod_autoscaling = true
# #   network_policy             = false


# #   node_pools = [
# #     {
# #       name               = "default-node-pool"
# #       machine_type       = "e2-small"
# #       node_locations     = "${var.instance_region}-a,${var.instance_region}-b"
# #       min_count          = 1
# #       max_count          = 8
# #       local_ssd_count    = 0
# #       disk_size_gb       = 10
# #       disk_type          = "pd-balanced"
# #       image_type         = "COS"
# #       auto_repair        = true
# #       auto_upgrade       = true
# #       service_account    = "project-service-account@prj-bu2-d-sample-base-aed2.iam.gserviceaccount.com" #google_service_account.project_sa.email
# #       preemptible        = false
# #       initial_node_count = 1
# #     },
# #   ]

# #   node_pools_oauth_scopes = {
# #     all = []

# #     default-node-pool = [
# #       "https://www.googleapis.com/auth/cloud-platform",
# #     ]
# #   }

# #   node_pools_labels = {
# #     all = {}

# #     default-node-pool = {
# #       default-node-pool = true
# #     }
# #   }

# #   node_pools_metadata = {
# #     all = {}

# #     default-node-pool = {
# #       node-pool-metadata-custom-value = "my-node-pool"
# #     }
# #   }

# #   node_pools_taints = {
# #     all = []

# #     default-node-pool = [
# #       {
# #         key    = "default-node-pool"
# #         value  = true
# #         effect = "PREFER_NO_SCHEDULE"
# #       },
# #     ]
# #   }

# #   node_pools_tags = {
# #     all = []

# #     default-node-pool = [
# #       "default-node-pool",
# #     ]
# #   }
# # }
