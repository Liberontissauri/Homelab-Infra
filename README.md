This is the terraform configuration for my homelab infrastructure.

# Overview

The configuration is divided in 2 stages:
- **stages/bootstrap**: Sets up MinIO (for Terraform remote state) and OpenBao (Vault for secrets management) with local state
- **stages/infra**: Main infrastructure with all services, using S3 remote state

Additionally:
- **modules/**: Reusable Terraform modules for specific services
- **scripts/**: Helper scripts for setup and configuration

## Setup from Scratch

### 1. Deploy Bootstrap Stage

Deploy MinIO and OpenBao with local Terraform state:

```bash
cd stages/bootstrap
tofu init
tofu apply
```

### 2. Run Bootstrap Setup Script

This script will:
- Create the S3 bucket for Terraform state in MinIO
- Initialize and unseal OpenBao (if not already done)
- Display credentials that must be saved securely

```bash
cd ../..
./setup-bootstrap.sh
```

**IMPORTANT**: The script will display the OpenBao unseal key and root token. Save these credentials securely (e.g., password manager, encrypted file). You will need the unseal key after every OpenBao restart.

### 3. Deploy Infrastructure Stage

Deploy all services using S3 remote state:

```bash
cd stages/infra
tofu init
tofu apply
```

## Backend Configuration

The infrastructure stage uses MinIO (S3-compatible storage) for remote state management. The backend is configured using a partial backend configuration approach:

- **`stages/infra/backend-config.hcl`**: Contains static S3 configuration (bucket, key, region, access credentials)
- **Environment variables**: Dynamic values are injected via the deployment workflow

The `tofu init` command combines these configurations:
```bash
tofu init \
  -backend-config=backend-config.hcl \
  -backend-config="endpoints={s3=\"http://$TF_VAR_homelab_ip:9000\"}" \
  -backend-config="secret_key=$TF_VAR_minio_root_password"
```

This approach:
- Keeps static config in version control
- Prevents hardcoding credentials or environment-specific values
- Supports multiple environments easily
- Works seamlessly with CI/CD workflows

## OpenBao (Vault) Management

### Unseal OpenBao (required after restarts)

OpenBao seals automatically on restart for security. The bootstrap script will unseal it initially, but after container restarts you must manually unseal:

```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
```

You will need to provide the unseal key from the initial setup.

### Access the UI

Once unsealed, access the OpenBao UI at: `https://vault.liberato.dev`

Login with the root token from the initialization.

