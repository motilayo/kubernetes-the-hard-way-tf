provider "aws" {
    region = "ca-central-1"
}

locals {
  resource_name = "kubernetes"
}

// create  resource for remote state
resource "aws_s3_bucket" "state_bucket" {
    bucket = "kth-terraform-backend"

    force_destroy = true


    tags = {
        Name = local.resource_name
    }
}

resource "aws_dynamodb_table" "state_lock" {
    name = "kth-tf-state"
    hash_key = "LockID"
    read_capacity = "8"
    write_capacity = "8"

    attribute {
      name = "LockID"
      type = "S"
    }

    tags = {
        Name = local.resource_name
    }
}