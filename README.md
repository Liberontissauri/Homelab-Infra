This is the terraform configuration for my homelab infrastructure.

# Overview

The configuration is divided in 4 parts:
- modules: reusable terraform modules for specific services
- stages/infra: main infrastructure with all my services
- stages/init: sets up Minio instance for terraform remote state
- stages/tfstate: connects to Minio instances and creates a bucket

to setup the homelab from scratch, you should deploy the stages in this order:
1. stages/init (local tfstate)
2. stages/tfstate (local tfstate)
3. stages/infra (s3 tfstate)

