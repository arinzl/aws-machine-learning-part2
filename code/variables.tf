
variable "region" {
  default = "ap-southeast-2"
  type    = string
}

variable "vpc_cidr_block_root" {
  type        = map(string)
  description = "VPD CIDR ranges per terraform workspace"
  default = {
    "default" : "10.32.0.0/16",
    "prod" : "10.16.0.0/16",
    "non-prod" : "10.32.0.0/16",
  }
}

variable "application_name" {
  default = "ml-reg-02"
  type    = string
}

