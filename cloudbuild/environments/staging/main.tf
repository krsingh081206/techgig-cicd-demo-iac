provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NETWORK TO DEPLOY THE GKE CLUSTER TO
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network" {
  source = "github.com/gruntwork-io/terraform-google-network.git//modules/vpc-network?ref=v0.8.2"
  #source= "github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network"
  name_prefix = "${var.cluster_name}-network-nw"
  project     = var.project
  region      = var.region

  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block

  public_subnetwork_secondary_range_name = var.public_subnetwork_secondary_range_name
  public_services_secondary_range_name   = var.public_services_secondary_range_name
  public_services_secondary_cidr_block   = var.public_services_secondary_cidr_block
  private_services_secondary_cidr_block  = var.private_services_secondary_cidr_block
  secondary_cidr_subnetwork_width_delta  = var.secondary_cidr_subnetwork_width_delta
  secondary_cidr_subnetwork_spacing      = var.secondary_cidr_subnetwork_spacing
}

# Use a random suffix to prevent overlap in network names
#resource "random_string" "suffix" {
#  length  = 4
#  special = false
#  upper   = false
#}