terraform {
    backend "s3" {
        bucket         = "kth-terraform-backend"
        key            = "terraform.tfstate"
        region         = "ca-central-1"
        encrypt        = true
        dynamodb_table = "kth-tf-state"
    }
}