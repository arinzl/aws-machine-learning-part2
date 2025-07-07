module "notebook" {
  source              = "./modules/notebook"
  cidr_block_module   = var.vpc_cidr_block_root[terraform.workspace]
  vpc_id              = module.networking.vpc-id
  vpc_private_subnets = module.networking.private_subnets
  app_name            = var.application_name
}
