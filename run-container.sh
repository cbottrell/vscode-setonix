#!/bin/bash

module load singularity/4.1.0-nompi

CONTAINER_DIR="$MYSOFTWARE/singularity/vscode-setonix"
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"
singularity pull "$CONTAINER_DIR/vscode-setonix.sif" docker://cbottrell/vscode-setonix:latest

# Setup SSH in fakeHome
FAKE_HOME="$MYSOFTWARE/fakeHome"
SSH_DIR="$FAKE_HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Copy SSH keys from host home to fakeHome
if [ -f /home/bottrell/.ssh/id_ed25519 ]; then
    cp /home/bottrell/.ssh/id_ed25519 "$SSH_DIR/id_ed25519"
    chmod 600 "$SSH_DIR/id_ed25519"
fi

# Create authorized_keys with both keys
cat > "$SSH_DIR/authorized_keys" <<'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyIhalpGsROR7zSDdD320e1dNgumhU8KOhCUwx7nf5Z connor.bottrell@gmail.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1yh92GkRxYxh8OHqTTeis5YdGST1VLtUJede7ac4wu bottrell@setonix
EOF

chmod 600 "$SSH_DIR/authorized_keys"

# Write compute node hostname for reference
hostname > "$FAKE_HOME/.container_host"

# Start Singularity container with SSH server
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"

singularity run --home="$FAKE_HOME" "$CONTAINER_IMAGE" &
echo "Container started with PID $!"
echo "Hostname written to $FAKE_HOME/.container_host"
