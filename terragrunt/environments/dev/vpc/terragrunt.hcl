include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/vpc"
}

inputs = {
  name     = "devto-dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2
}
