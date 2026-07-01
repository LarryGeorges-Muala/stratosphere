variable "disaster_recovery_enabled" {
  type        = bool
  default     = false
  description = "Enable disaster recovery setup across 2 regions"
}

variable "az_resource_id" {
  type        = string
  default     = ""
  description = "AZ Resource ID used to generate auth token"
}
