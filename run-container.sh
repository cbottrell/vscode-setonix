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
if [ -f $HOME/.ssh/id_ed25519 ]; then
    cp $HOME/.ssh/id_ed25519 "$SSH_DIR/id_ed25519"
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

# Build environment string to pass into container
# Include SLURM variables and custom variables
ENV_VARS="MYSOFTWARE=$MYSOFTWARE,MYSCRATCH=$MYSCRATCH"
ENV_VARS="$ENV_VARS,SLURM_NODELIST=$SLURM_NODELIST"
ENV_VARS="$ENV_VARS,SLURM_NNODES=$SLURM_NNODES"
ENV_VARS="$ENV_VARS,SLURM_NTASKS=$SLURM_NTASKS"
ENV_VARS="$ENV_VARS,SLURM_CPUS_PER_TASK=$SLURM_CPUS_PER_TASK"
ENV_VARS="$ENV_VARS,SLURM_JOB_ID=$SLURM_JOB_ID"
ENV_VARS="$ENV_VARS,SLURM_JOB_NAME=$SLURM_JOB_NAME"
ENV_VARS="$ENV_VARS,SLURM_SUBMIT_DIR=$SLURM_SUBMIT_DIR"
ENV_VARS="$ENV_VARS,SLURM_SUBMIT_HOST=$SLURM_SUBMIT_HOST"
ENV_VARS="$ENV_VARS,SLURM_PARTITION=$SLURM_PARTITION"
ENV_VARS="$ENV_VARS,SLURM_ACCOUNT=$SLURM_ACCOUNT"
ENV_VARS="$ENV_VARS,SLURM_MEM_PER_NODE=$SLURM_MEM_PER_NODE"
ENV_VARS="$ENV_VARS,SLURM_TIME_LIMIT=$SLURM_TIME_LIMIT"
ENV_VARS="$ENV_VARS,SLURM_ARRAY_JOB_ID=$SLURM_ARRAY_JOB_ID"

# Start Singularity container with SSH server
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"

singularity run --env "$ENV_VARS" --home="$FAKE_HOME" "$CONTAINER_IMAGE" &
echo "Container started with PID $!"
echo "Hostname written to $FAKE_HOME/.container_host"
