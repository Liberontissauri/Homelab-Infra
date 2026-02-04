terraform {
    required_providers {
        minio = {
            source  = "aminueza/minio"
            version = "~> 3.17.0"
        }
    }
}

provider "minio" {
    minio_server = "${var.homelab_ip}:9000"
    minio_user  = var.minio_root_user
    minio_password = var.minio_root_password
}

resource "minio_s3_bucket" "tf_state_bucket" {
    bucket = var.tf_state_bucket_name
}