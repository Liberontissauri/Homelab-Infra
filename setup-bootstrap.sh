#!/bin/bash
set -e

# Configuration
HOMELAB_IP="${1:-192.168.1.111}"
MINIO_ROOT_USER="admin"
MINIO_ROOT_PASSWORD="${2:-@4m>pO76TO5%}"
BUCKET_NAME="tf-state-bucket"
MINIO_URL="http://${HOMELAB_IP}:9000"
VAULT_ADDR="http://${HOMELAB_IP}:8200"

echo "=========================================="
echo "Homelab Bootstrap Setup"
echo "=========================================="
echo ""

# Check if required commands are available
if ! command -v docker &> /dev/null; then
    echo "Error: docker command not found. Please install Docker."
    exit 1
fi

# Wait for MinIO to be ready
echo "⏳ Waiting for MinIO to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec minio mc ready local &> /dev/null; then
        echo "✅ MinIO is ready"
        break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ MinIO failed to become ready after ${max_attempts} attempts"
        exit 1
    fi
    sleep 2
done

# Configure MinIO client alias
echo ""
echo "⚙️  Configuring MinIO client..."
docker exec minio mc alias set local http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" &> /dev/null
echo "✅ MinIO client configured"

# Create bucket if it doesn't exist (idempotent)
echo ""
echo "📦 Creating Terraform state bucket..."
if docker exec minio mc ls "local/${BUCKET_NAME}" &> /dev/null; then
    echo "ℹ️  Bucket '${BUCKET_NAME}' already exists, skipping creation"
else
    docker exec minio mc mb "local/${BUCKET_NAME}"
    echo "✅ Bucket '${BUCKET_NAME}' created successfully"
fi

# Enable versioning on the bucket for state safety
echo ""
echo "🔄 Enabling bucket versioning..."
docker exec minio mc version enable "local/${BUCKET_NAME}"
echo "✅ Bucket versioning enabled"

# Wait for OpenBao to be ready
echo ""
echo "⏳ Waiting for OpenBao (Vault) to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -sf "${VAULT_ADDR}/v1/sys/health" &> /dev/null || \
       curl -sf "${VAULT_ADDR}/v1/sys/seal-status" &> /dev/null; then
        echo "✅ OpenBao is ready"
        break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ OpenBao failed to become ready after ${max_attempts} attempts"
        exit 1
    fi
    sleep 2
done

# Check if OpenBao is already initialized (idempotent)
echo ""
echo "🔐 Checking OpenBao initialization status..."
init_status=$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao status -format=json 2>/dev/null | grep -o '"initialized":[^,]*' || echo "")

if echo "$init_status" | grep -q "true"; then
    echo "ℹ️  OpenBao is already initialized"
    
    # Check if it's sealed
    seal_status=$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao status -format=json 2>/dev/null | grep -o '"sealed":[^,]*' || echo "")
    
    if echo "$seal_status" | grep -q "true"; then
        echo ""
        echo "🔓 OpenBao is sealed. Please unseal it manually:"
        echo ""
        echo "   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao operator unseal"
        echo ""
        echo "   You will need to provide the unseal key from the initial setup."
    else
        echo "✅ OpenBao is already unsealed and ready"
    fi
else
    echo "🚀 Initializing OpenBao for the first time..."
    echo ""
    
    # Initialize OpenBao
    init_output=$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao operator init -key-shares=1 -key-threshold=1)
    
    echo "=========================================="
    echo "⚠️  IMPORTANT: SAVE THESE CREDENTIALS"
    echo "=========================================="
    echo ""
    echo "$init_output"
    echo ""
    echo "=========================================="
    echo ""
    echo "✅ OpenBao initialized successfully"
    echo ""
    echo "⚠️  CRITICAL: Save the unseal key and root token above in a secure location"
    echo "   (e.g., password manager, encrypted file)"
    echo ""
    echo "   You will need the unseal key every time OpenBao restarts."
    echo ""
    
    # Automatically unseal with the key from init output
    unseal_key=$(echo "$init_output" | grep "Unseal Key 1:" | awk '{print $NF}')
    
    if [ -n "$unseal_key" ]; then
        echo "🔓 Unsealing OpenBao..."
        echo "$unseal_key" | docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 openbao bao operator unseal &> /dev/null
        echo "✅ OpenBao unsealed successfully"
    fi
fi

echo ""
echo "=========================================="
echo "✅ Bootstrap Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Make sure you've saved the OpenBao credentials securely"
echo "  2. Deploy the infra stage:"
echo "     cd stages/infra"
echo "     tofu init"
echo "     tofu apply"
echo ""
echo "OpenBao UI: https://vault.liberato.dev"
echo "MinIO endpoint: ${MINIO_URL}"
echo ""
