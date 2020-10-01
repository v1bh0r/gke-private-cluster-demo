#!/usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################
#
# Creates all resources with Terraform.
#
###############################################################################

# Bash safeties: exit on error, no unset variables, pipelines can't hide errors
set -o errexit
set -o nounset
set -o pipefail

# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=scripts/common.sh
source "${ROOT}/scripts/common.sh"

# Generate the variables to be used by Terraform
# shellcheck source=scripts/generate-tfvars.sh
# TODO remove this
#source "${ROOT}/scripts/generate-tfvars.sh"

# Initialize and run Terraform
(cd "${ROOT}/terraform"; terraform init -input=false)
(cd "${ROOT}/terraform"; terraform apply -input=false -auto-approve)

# Get cluster credentials
GET_CREDS="$(terraform output --state=terraform/terraform.tfstate get_credentials)"
${GET_CREDS}

# The databases need some database migrations to run when used for the first-time
source "${ROOT}/scripts/run-database-migrations.sh"
