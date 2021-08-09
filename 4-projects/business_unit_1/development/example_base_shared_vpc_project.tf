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

module "base_shared_vpc_project" {
  source                      = "../../modules/single_project"
  impersonate_service_account = var.terraform_service_account
  org_id                      = var.org_id
  billing_account             = var.billing_account
  folder_id                   = data.google_active_folder.env.name
  environment                 = "development"
  vpc_type                    = "base"
  alert_spent_percents        = var.alert_spent_percents
  alert_pubsub_topic          = var.alert_pubsub_topic
  budget_amount               = var.budget_amount
  project_prefix              = var.project_prefix
  enable_hub_and_spoke        = var.enable_hub_and_spoke
  enable_cloudbuild_deploy    = true
  cloudbuild_sa               = var.app_infra_pipeline_cloudbuild_sa
  // Review the following Cloud Build service account roles
  // The person deploying these rules should be different from the person deploying workloads
  sa_roles = [
    "roles/editor",
    "roles/compute.viewer",
    "roles/compute.instanceAdmin.v1",
    "roles/container.clusterAdmin",
    "roles/container.developer",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/logging.configWriter",
    "roles/storage.objectViewer",
    "roles/iap.admin",
    "roles/iam.roleAdmin",
    "roles/binaryauthorization.policyEditor",
    "roles/compute.securityAdmin",
    "roles/compute.publicIpAdmin"
  ]
  activate_apis = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "oslogin.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "storage-api.googleapis.com",
    "servicenetworking.googleapis.com"
  ]

  # Metadata
  project_suffix    = "sample-base"
  application_name  = "bu1-sample-application"
  billing_code      = "1234"
  primary_contact   = "example@example.com"
  secondary_contact = "example2@example.com"
  business_code     = "bu1"
  workload_type     = "standard"
}

