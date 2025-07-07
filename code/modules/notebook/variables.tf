
variable "app_name" {
  description = "Name of application or project in module"
  type        = string
}


variable "cidr_block_module" {
  description = "The cidr block for the account"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the notebook/ec2 instances into"
  type        = string
}

variable "vpc_private_subnets" {
  description = "notebook VPC private subnet IDs"
  type        = list(string)
}
