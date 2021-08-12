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

locals {
  environment_code = element(split("", var.environment), 0)
}

# Startup script for VM
data "template_file" "nginx" {
  # Runs a simple Nginx web server to indicate which server it's running from using Compute Metadata
  template = file("${path.module}/templates/install_nginx.tpl")

  vars = {
    ufw_allow_nginx = "Nginx Full"
  }
}

# Startup script to install kubectl on Debian-based machines
data "template_file" "install_kubectl" {
  template = file("${path.module}/templates/install_kubectl.tpl")
}
