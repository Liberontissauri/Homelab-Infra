#!/bin/sh
set -e

mkdir -p ~/.ssh
echo "$SSH_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

apk add --no-cache openssh-client

ssh-keyscan -H $TF_VAR_homelab_ip >> ~/.ssh/known_hosts
ssh-keyscan -H $TF_VAR_vps_ip >> ~/.ssh/known_hosts
