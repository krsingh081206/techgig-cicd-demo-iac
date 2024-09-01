variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "rd-application-group"
}

variable "network_name" {
  description = "The ID of the network in which to provision resources."
  type        = string
  default     = "example-private-cluster-network-network"
}


variable "region" {
  default     = "us-east4"
  description = "The region to apply resources within"
  type        = string
}