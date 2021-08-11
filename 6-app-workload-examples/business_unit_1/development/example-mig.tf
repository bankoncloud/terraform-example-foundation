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

## This example meets the existing Terraform Validator policies.

# Creates a Managed Instance Group using an Instance Template (Ubuntu 18.04 LTS)
#  with egress-internet that's connected to a Cloud NAT
# https://registry.terraform.io/modules/terraform-google-modules/vm/google/latest/submodules/mig
resource "google_service_account" "compute_mig_service_account" {
  project      = data.google_project.env_project.project_id
  account_id   = "mig-example-app"
  display_name = "Compute Managed Instance Group service account"
}

# Instance template for VM
module "mig_instance_template" {
  source                 = "terraform-google-modules/vm/google//modules/instance_template"
  version                = "7.0.0"
  machine_type           = "n2d-standard-2" # Minimum for Confidential Compute VMs
  region                 = var.region
  source_image_family    = "ubuntu-1804-lts"
  source_image_project   = "ubuntu-os-cloud"
  startup_script         = data.template_file.nginx.rendered
  project_id             = data.google_project.env_project.project_id
  subnetwork             = data.google_compute_subnetwork.subnetwork.self_link
  enable_confidential_vm = true
  tags                   = ["egress-internet", "allow-lb"]
  service_account = {
    email  = google_service_account.compute_mig_service_account.email
    scopes = ["compute-rw"]
  }
}

# The actual Managed Instance Group
module "vm_mig" {
  source              = "terraform-google-modules/vm/google//modules/mig"
  version             = "7.0.0"
  hostname            = "terraform-example"
  instance_template   = module.mig_instance_template.self_link
  project_id          = data.google_project.env_project.project_id
  region              = var.region
  autoscaling_enabled = true
  autoscaling_cpu = [{
    target = 0.6
  }]
  named_ports = [{
    name = "http"
    port = 80
  }]
  min_replicas = 2
}

# HTTP Load Balancer
module "gce-lb-http" {
  source            = "GoogleCloudPlatform/lb-http/google"
  version           = "~> 5.1"
  name              = "group-http-lb"
  project           = data.google_project.env_project.project_id
  target_tags       = ["allow-lb"]
  firewall_projects = [data.google_project.network_project.project_id]
  firewall_networks = [data.google_compute_network.shared_vpc.name]

  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 10
      connection_draining_timeout_sec = null
      enable_cdn                      = false
      security_policy                 = google_compute_security_policy.example_policy.self_link
      session_affinity                = null
      affinity_cookie_ttl_sec         = null
      custom_request_headers          = null
      custom_response_headers         = null

      health_check = {
        check_interval_sec  = null
        timeout_sec         = null
        healthy_threshold   = null
        unhealthy_threshold = null
        request_path        = "/"
        port                = 80
        host                = null
        logging             = null
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group                        = module.vm_mig.instance_group
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
    }
  }
}
