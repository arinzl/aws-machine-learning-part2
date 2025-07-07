locals {
  filtered_azs = [for az in data.aws_availability_zones.available.names : az if az != "ap-southeast-2-akl-1a"]
}
