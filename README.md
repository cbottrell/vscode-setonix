# VS Code + Singularity Container for setonix

A containerized development environment using Ubuntu 22.04 with SSH server, allowing remote VS Code connections to compute nodes on the Pawsey setonix supercomputer.

## Features

- **SSH-based access** on port 9300
- **Key-based authentication** (no passwords)
- **X11 forwarding** support
- **Python 3.10** with pip
- **Runs on compute nodes** via SLURM scheduler
- **Accessible from Mac/Linux** via ProxyJump through login node

## Quick Start

### 1. Run the Container on setonix

Submit the job to run the container on a compute node:

```bash
cd /software/projects/pawsey1149/bottrell/singularity/vscode-setonix
sbatch submit-container.sh
```

Watch the output:
```bash
tail -f dev.out
```

**Note:** Running the container automatically creates a `$MYSOFTWARE/fakeHome` folder. This directory contains all VS Code cache and extensions that persist across container runtimes and rebuilds, enabling a consistent development environment.

### 2. Get the Compute Node Hostname

```bash
bash get-container-host.sh
```

Output will show something like:
```
Container is running on: nid001234

Update your ~/.ssh/vscode-setonix_config.txt vscode-setonix entry with:
    HostName nid001234
```

### 3. Configure SSH on Your Mac

If you haven't already set up SSH for setonix, add to `~/.ssh/config`:

```
Include ~/.ssh/vscode-setonix_config.txt

Host setonix.pawsey.org.au
    HostName setonix.pawsey.org.au
    User bottrell

Host setonix
    HostName setonix.pawsey.org.au
    User bottrell

Host nid*
    User bottrell
    ProxyJump setonix
```

Then create or update `~/.ssh/vscode-setonix_config.txt`:

```
Host vscode-setonix
    HostName nid001234          # Replace with output from get-container-host.sh
    Port 9300
    User bottrell
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    ProxyJump setonix
```

### 4. Connect

**From terminal:**
```bash
ssh vscode-setonix
```

**From VS Code:**
- Install **Remote - SSH** extension
- Open command palette: `Cmd+Shift+P` → "Remote-SSH: Connect to Host..."
- Select `vscode-setonix`
- Open a folder: `/software/projects/pawsey1149/bottrell/fakeHome`

## Building and Deploying the Container

### Build on Mac

The container must be built for AMD64 (setonix architecture):

```bash
# Navigate to repo
cd /path/to/vscode-setonix

# Build and push to Docker Hub
docker buildx build --platform linux/amd64 --push -t cbottrell/vscode-setonix:latest .
```

Requires: `docker buildx` (available in Docker Desktop)

### Pull on setonix

After pushing to Docker Hub:

```bash
module load singularity/4.1.0-nompi
cd /software/projects/pawsey1149/bottrell/singularity/vscode-setonix

# Pull and convert to Singularity format
singularity pull --force vscode-setonix.sif docker://cbottrell/vscode-setonix:latest
```

This creates `vscode-setonix.sif` (Singularity image file).

## Files Overview

| File | Purpose |
|------|---------|
| `Dockerfile` | Container definition with SSH, Ubuntu 22.04 |
| `run-container.sh` | Startup script: sets up SSH keys, writes hostname, runs container |
| `get-container-host.sh` | Helper to retrieve compute node hostname for SSH config |
| `submit-container.sh` | SLURM batch script to submit container job |
| `cvaltdm-dev.sif` | Singularity image (generated locally) |

## Container Details

- **Base OS:** Ubuntu 22.04 LTS
- **SSH Port:** 9300 (inside container)
- **SSH Config:**
  - Key-based auth only
  - X11 forwarding enabled
  - PAM disabled (non-root sshd)
  - StrictModes disabled (for mounted home)
  - Root login disabled

- **User:** `bottrell` (UID 25420 - matches host for mounted filesystem)
- **Home:** `/software/projects/pawsey1149/bottrell/fakeHome` (mounted from host)
- **SSH Keys:** Copied to fakeHome's `.ssh/` by `run-container.sh`

## Troubleshooting

**SSH Connection Refused**
- Verify container is running: `squeue -u bottrell`
- Check compute node name: `bash get-container-host.sh`
- Update SSH config with correct hostname
- Ensure `run-container.sh` completed (check `dev.out`)

**"No such file or directory" for SSH key**
- Ensure `~/.ssh/id_ed25519` exists on setonix host
- Check permissions: `chmod 600 ~/.ssh/id_ed25519`

**Container times out**
- Increase `--time` in `submit-container.sh` (default 12 hours)
- Resubmit job before it expires

**VS Code can't access fakeHome files**
- Check `$MYSOFTWARE` is set: `echo $MYSOFTWARE`
- Verify fakeHome exists: `ls $MYSOFTWARE/fakeHome`
- Ensure SSH connection works first: `ssh vscode-container whoami`

## Environment Variables

The container uses:
- `MYSOFTWARE` - Base path for fakeHome (set on setonix login nodes)
- `$MYSOFTWARE/fakeHome` - Container home directory (mounted via `--home` flag)
- `$MYSOFTWARE/fakeHome/.container_host` - Hostname file (written by `run-container.sh`)

## Advanced Usage

### Extend Container

Add packages by modifying the `Dockerfile`:

```dockerfile
# Install additional packages
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
```

Then rebuild:
```bash
docker buildx build --platform linux/amd64 --push -t cbottrell/cvaltdm-dev:latest .
```

### Run Longer Jobs

Modify `submit-container.sh`:

```bash
#SBATCH --time=24:00:00  # 24 hours
```

### Use Different Allocation

Modify `submit-container.sh`:

```bash
#SBATCH --account=pawsey1149  # Change project code
```

## Project Info

- **GitHub:** https://github.com/cbottrell/vscode-cvaltdm
- **Docker Hub:** https://hub.docker.com/r/cbottrell/cvaltdm-dev
- **Pawsey Project:** pawsey1149
- **Base Image:** Ubuntu 22.04 LTS
