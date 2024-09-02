
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

data "google_compute_subnetwork" "subnetwork" {
  name   = var.subnet_name
  project = var.project_id
  region = var.region
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

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY ALLOYDB IN GCP
# ---------------------------------------------------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# ---------------------------------------------------------------------------------------------------------------------

module "gke_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.2.0"
  source = "../../modules/gke-cluster"

  name = var.cluster_name

  project  = var.project_id
  location = var.region
  network  = data.google_compute_network.network.id

  # We're deploying the cluster in the 'public' subnetwork to allow outbound internet access
  # See the network access tier table for full details:
  # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
  subnetwork                    = data.google_compute_subnetwork.subnetwork.self_link
  cluster_secondary_range_name  = var.public_subnetwork_secondary_range_name
  services_secondary_range_name = var.public_services_secondary_range_name

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

  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling

  resource_labels = {
    environment = "testing"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NODE POOL
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  name     = "private-pool"
  project  = var.project_id
  location = var.region
  cluster  = module.gke_cluster.name

  initial_node_count = "1"

  autoscaling {
    min_node_count = "1"
    max_node_count = "5"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "cos_containerd"
    machine_type = "n2-standard-2"

    labels = {
      private-pools-example = "true"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      data.google_compute_network.network.name,
      "private-pool-example",
    ]

    disk_size_gb = "30"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = "example-private-cluster-sa@rd-application-group.iam.gserviceaccount.com"

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

