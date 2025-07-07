
module "networking" {
  source = "./modules/network"

  cidr_block_module = var.vpc_cidr_block_root[terraform.workspace]
  app_name          = var.application_name

  providers = {
    aws = aws
  }
}

