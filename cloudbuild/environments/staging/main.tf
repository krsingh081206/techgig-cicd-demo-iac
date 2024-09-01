/**
 * Copyright 2023 Google LLC
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

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_string" "key_suffix" {
  length  = 3
  special = false
  upper   = false
}

data "google_compute_network" "network" {
  name = var.network_name
  project = var.project_id
}

resource "google_kms_key_ring" "keyring" {
  project  = var.project_id
  name     = "alloydb-keyring-example-${random_string.key_suffix.result}"
  location = "us-east4"
}

resource "google_kms_crypto_key" "key" {
  name     = "crypto-key-example-${random_string.key_suffix.result}"
  key_ring = google_kms_key_ring.keyring.id
}

resource "google_project_service_identity" "alloydb_sa" {
  provider = google-beta

  project = var.project_id
  service = "alloydb.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "alloydb_sa_iam" {
  crypto_key_id = google_kms_crypto_key.key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.alloydb_sa.email}"
}


module "alloydb" {
  source           = "../../modules/alloydb"
  cluster_id       = "alloydb-v6-cluster"
  cluster_location = var.region
  project_id       = var.project_id

  network_self_link           = "projects/${var.project_id}/global/networks/${var.network_name}"
  cluster_encryption_key_name = google_kms_crypto_key.key.id

  automated_backup_policy = {
    location      = "us-east4"
    backup_window = "1800s"
    enabled       = true
    weekly_schedule = {
      days_of_week = ["FRIDAY"],
      start_times  = ["2:00:00:00", ]
    }
    quantity_based_retention_count = 1
    time_based_retention_count     = null
    labels = {
      test = "alloydb-cluster-with-prim"
    }
    backup_encryption_key_name = google_kms_crypto_key.key.id
  }

  continuous_backup_recovery_window_days = 10
  continuous_backup_encryption_key_name  = google_kms_crypto_key.key.id

  primary_instance = {
    instance_id   = "primary-instance-1",
    instance_type = "PRIMARY",
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    require_connectors = false

  }

  read_pool_instance = null

  depends_on = [
    
    google_compute_global_address.private_ip_alloc,
    google_service_networking_connection.vpc_connection,
    google_kms_crypto_key_iam_member.alloydb_sa_iam,
  ]
}



resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "adb-v6"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       =  data.google_compute_network.network.id
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = data.google_compute_network.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

