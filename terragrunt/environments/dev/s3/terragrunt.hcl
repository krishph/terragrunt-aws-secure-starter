include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/s3"
}

inputs = {
  bucket_name        = "krishph-devto-dev-app"
  versioning_enabled = true
}
