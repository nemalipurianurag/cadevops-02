variable "region" {
  description = "Region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "project_id" {
  type    = string
  default = "modular-scout-345114"
}

# variable "kms_keyring" {
#   description = "KMS Keyring used for encryption keys"
#   type        = string 
# }
