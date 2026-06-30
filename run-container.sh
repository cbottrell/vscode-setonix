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
# Conda/Python environment from the Jupyter base image
export PATH="/opt/conda/bin:\$PATH"

# Setonix environment
export MYSOFTWARE=$MYSOFTWARE
export MYSCRATCH=$MYSCRATCH
export SLURM_NODELIST=$SLURM_NODELIST
export SLURM_NNODES=$SLURM_NNODES
export SLURM_NTASKS=$SLURM_NTASKS
export SLURM_CPUS_PER_TASK=$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=$OMP_NUM_THREADS
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
    if ! grep -q 'export PS1' "$BASHRC"; then
        echo "export PS1='\u@\h:\W$ '" >> "$BASHRC"
    fi
else
    echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' > "$BASHRC"
    echo "export PS1='\u@\h:\W$ '" >> "$BASHRC"
fi

if [ -f "$BASH_PROFILE" ]; then
    if ! grep -q '.env.singularity' "$BASH_PROFILE"; then
        echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' >> "$BASH_PROFILE"
    fi
    if ! grep -q 'export PS1' "$BASH_PROFILE"; then
        echo "export PS1='\u@\h:\W$ '" >> "$BASH_PROFILE"
    fi
else
    echo '[ -f ~/.env.singularity ] && source ~/.env.singularity' > "$BASH_PROFILE"
    echo "export PS1='\u@\h:\W$ '" >> "$BASH_PROFILE"
fi

# Start Singularity container with SSH server
# Note: setonix singularity module handles environment variables for direct execution,
# but not for SSH logins. The .env.singularity file handles variables for SSH sessions.
CONTAINER_IMAGE="$CONTAINER_DIR/vscode-setonix.sif"

echo "Starting SSH container..."
singularity run --home="$FAKE_HOME" "$CONTAINER_IMAGE" &
CONTAINER_PID=$!
echo "Container started with PID $CONTAINER_PID"

# Wait briefly for sshd to initialize. The SLURM job can remain alive even if
# the container exits, so check the process and port before reporting success.
sleep 3

if ! ps -p "$CONTAINER_PID" >/dev/null 2>&1; then
    echo "ERROR: Singularity container exited before SSH was ready."
    echo "Check the SLURM output above for sshd or container startup errors."
    exit 1
fi

PORT_LISTENING="unknown"
if command -v ss >/dev/null 2>&1; then
    if ss -tuln | grep -q ':9300'; then
        PORT_LISTENING="yes"
    else
        PORT_LISTENING="no"
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ':9300'; then
        PORT_LISTENING="yes"
    else
        PORT_LISTENING="no"
    fi
fi

if [ "$PORT_LISTENING" = "yes" ]; then
    echo "SSH server is listening on port 9300"
elif [ "$PORT_LISTENING" = "no" ]; then
    echo "ERROR: SSH server is not listening on port 9300."
    echo "If another container on this node already uses port 9300, cancel it or change one container's SSH port."
    echo "Checking sshd processes inside the image:"
    singularity exec --home="$FAKE_HOME" "$CONTAINER_IMAGE" ps aux | grep '[s]shd' || true
    exit 1
else
    echo "WARNING: Could not verify port 9300 because neither ss nor netstat is available."
    echo "Checking sshd processes inside the image:"
    singularity exec --home="$FAKE_HOME" "$CONTAINER_IMAGE" ps aux | grep '[s]shd' || true
fi

echo "Hostname written to $FAKE_HOME/.container_host"
echo "Container hostname:"
cat "$FAKE_HOME/.container_host"
