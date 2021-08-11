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

## Example GKE Safer Cluster

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
