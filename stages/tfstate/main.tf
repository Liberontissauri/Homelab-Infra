terraform {
    required_providers {
        minio = {
            source  = "aminueza/minio"
            version = "~> 3.17.0"
        }
    }
}

module "bucket" {
    source = "../../modules/bucket"
    minio_root_user     = "admin"
    minio_root_password = var.minio_root_password
    homelab_ip         = var.homelab_ip
    tf_state_bucket_name = var.tf_state_bucket_name
}