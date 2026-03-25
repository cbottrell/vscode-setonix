#!/bin/bash

module load singularity/4.1.0-nompi

CONTAINER_DIR="$MYSOFTWARE/singularity/vscode-setonix"
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"
singularity pull --force "$CONTAINER_DIR/vscode-setonix.sif" docker://cbottrell/vscode-setonix:latest

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

# Write environment variables to a file that can be sourced in the container
# This ensures variables are available in SSH login shells
cat > "$FAKE_HOME/.env.singularity" <<EOF
export MYSOFTWARE=$MYSOFTWARE
export MYSCRATCH=$MYSCRATCH
export SLURM_NODELIST=$SLURM_NODELIST
export SLURM_NNODES=$SLURM_NNODES
export SLURM_NTASKS=$SLURM_NTASKS
export SLURM_CPUS_PER_TASK=$SLURM_CPUS_PER_TASK
export SLURM_JOB_ID=$SLURM_JOB_ID
export SLURM_JOB_NAME=$SLURM_JOB_NAME
export SLURM_SUBMIT_DIR=$SLURM_SUBMIT_DIR
export SLURM_SUBMIT_HOST=$SLURM_SUBMIT_HOST
export SLURM_PARTITION=$SLURM_PARTITION
export SLURM_ACCOUNT=$SLURM_ACCOUNT
export SLURM_MEM_PER_NODE=$SLURM_MEM_PER_NODE
export SLURM_TIME_LIMIT=$SLURM_TIME_LIMIT
export SLURM_ARRAY_JOB_ID=$SLURM_ARRAY_JOB_ID
EOF
chmod 644 "$FAKE_HOME/.env.singularity"

# Ensure .bashrc and .bash_profile in fakeHome source the environment variables for SSH logins
# SSH login shells read .bash_profile first, so we update both for compatibility
BASHRC="$FAKE_HOME/.bashrc"
BASH_PROFILE="$FAKE_HOME/.bash_profile"

if [ -f "$BASHRC" ]; then
    if ! grep -q '.env.singularity' "$BASHRC"; then
        echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' >> "$BASHRC"
    fi
else
    echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' > "$BASHRC"
fi

if [ -f "$BASH_PROFILE" ]; then
    if ! grep -q '.env.singularity' "$BASH_PROFILE"; then
        echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' >> "$BASH_PROFILE"
    fi
else
    echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' > "$BASH_PROFILE"
fi

# Start Singularity container with SSH server
# Note: setonix singularity module handles environment variables for direct execution,
# but not for SSH logins. The .env.singularity file handles variables for SSH sessions.
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"

singularity run --home="$FAKE_HOME" "$CONTAINER_IMAGE" &
echo "Container started with PID $!"
echo "Hostname written to $FAKE_HOME/.container_host"
