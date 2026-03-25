# VS Code + Singularity Container for setonix

A containerized development environment using Ubuntu 22.04 with SSH server, allowing remote VS Code connections to compute nodes on the Pawsey setonix supercomputer.

## Features

- **SSH-based access** on port 9300
- **Key-based authentication** (no passwords)
- **X11 forwarding** support
- **Python 3.10** with pip
- **Runs on compute nodes** via SLURM scheduler
- **Accessible from Mac/Linux** via ProxyJump through login node

## Prerequisites

Before getting started, you'll need:

- **Docker Desktop** on your local machine (with `docker buildx` support)
- **Docker Hub account** (free at https://hub.docker.com)
- SSH access to setonix
- Your **setonix username** and **user ID (UID/GID)**
- Your **Pawsey project code** (e.g., `pawsey1149`)

## Step 1: Get Your setonix User Information

**On setonix**, get your username and user IDs:

```bash
ssh setonix
id
# Output: uid=1234(myusername) gid=1234(myusername) groups=...
```

Save your `uid`, `gid`, and username - you'll need these in the next step.

## Step 2: Customize the Dockerfile for Your User

The `Dockerfile` contains hardcoded user information that **must** be customized for your account. Different users must rebuild the image with their own credentials.

1. Clone this repository on your local machine:
```bash
git clone https://github.com/cbottrell/vscode-setonix.git
cd vscode-setonix
```

2. Edit the `Dockerfile` and find this section (around line 22):
```dockerfile
# Create user with matching host UID/GID
RUN groupadd -g 25420 bottrell && \
    useradd -m -u 25420 -g 25420 -s /bin/bash bottrell
```

3. Replace with **YOUR** setonix credentials:
```dockerfile
# Create user with matching host UID/GID
RUN groupadd -g <YOUR_GID> <YOUR_USERNAME> && \
    useradd -m -u <YOUR_UID> -g <YOUR_GID> -s /bin/bash <YOUR_USERNAME>
```

Replace `<YOUR_UID>`, `<YOUR_GID>`, and `<YOUR_USERNAME>` with values from Step 1.

## Step 3: Build and Push to Docker Hub

Now build the Docker image with your credentials and push it to your Docker Hub account.

**On your local machine:**

```bash
# Navigate to repo
cd /path/to/vscode-setonix

# Log in to Docker Hub
docker login

# Build and push (replace <DOCKER_USERNAME> with your Docker Hub username)
docker buildx build --platform linux/amd64 --push -t <DOCKER_USERNAME>/vscode-setonix:latest .
```

**Note:** This builds for AMD64 (setonix architecture) and pushes directly to Docker Hub.

## Step 4: Set Up SSH Keys

Generate SSH keys (if needed) on both your local machine and setonix, then update `run-container.sh` with both public keys.

### Generate SSH Keys (if needed)

**On your local machine:**
```bash
# Generate a new Ed25519 key (recommended)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Or if your system doesn't support Ed25519, use RSA:
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

Press Enter at all prompts to use defaults. Your keys will be saved to `~/.ssh/id_ed25519` (or `~/.ssh/id_rsa`).

**On setonix:**
```bash
ssh setonix
ssh-keygen -t ed25519 -C "your-setonix-email@example.com"
# Press Enter at all prompts
exit
```

### Update run-container.sh with Your SSH Keys

You **must** edit `run-container.sh` and replace the default `authorized_keys` with your own keys.

1. Get your local machine's public key:
```bash
cat ~/.ssh/id_ed25519.pub  # or ~/.ssh/id_rsa.pub
```

2. Get your setonix public key:
```bash
ssh setonix
cat ~/.ssh/id_ed25519.pub  # or ~/.ssh/id_rsa.pub
exit
```

3. On your local machine, edit `run-container.sh` and update the `authorized_keys` section (around line 20):

```bash
cat > "$SSH_DIR/authorized_keys" <<'EOF'
<your local machine public key>
<your setonix public key>
EOF
```

Each key should be on its own line.

4. Commit and push these changes back to the repo (or keep them local):
```bash
git add run-container.sh
git commit -m "Add SSH keys for my account"
git push  # Only if you have write access, or push to your own fork
```

## Step 5: Use on setonix

Now that you've built and pushed your custom image, you can use it on setonix.

### Clone Repository on setonix

```bash
ssh setonix
mkdir -p $MYSOFTWARE/singularity
cd $MYSOFTWARE/singularity
git clone https://github.com/cbottrell/vscode-setonix.git
cd vscode-setonix
```

If you forked the repo and updated SSH keys there, clone your fork instead.

### Pull the Singularity Image

```bash
module load singularity/4.1.0-nompi
cd $MYSOFTWARE/singularity/vscode-setonix

# Pull and convert to Singularity format (use your Docker Hub username)
singularity pull vscode-setonix.sif docker://<DOCKER_USERNAME>/vscode-setonix:latest
```

This creates `vscode-setonix.sif` (Singularity image file).

### Customize submit-container.sh with Your Pawsey Project

Before submitting the job, you must update `submit-container.sh` with your Pawsey project code. SLURM does not support environment variables in batch directives, so this **must be hardcoded**.

1. Edit `submit-container.sh` and find line 2:
```bash
#SBATCH --account=pawsey1149
```

2. Replace `pawsey1149` with your actual project code:
```bash
#SBATCH --account=<YOUR_PAWSEY_PROJECT_CODE>
```

To find your project code, run:
```bash
ssh setonix
my_projects  # Lists all your project IDs
```

### Submit Container Job

```bash
cd $MYSOFTWARE/singularity/vscode-setonix
sbatch submit-container.sh
```

Watch the output:
```bash
tail -f dev-container.out
```

**Note:** Running the container automatically creates a `$MYSOFTWARE/fakeHome` folder. This directory contains all VS Code cache and extensions that persist across container runtimes and rebuilds.

### Get the Compute Node Hostname

```bash
bash get-container-host.sh
```

Output will show something like:
```
Container is running on: nid001234

Update your ~/.ssh/vscode-setonix_config.txt vscode-setonix entry with:
    HostName nid001234
```

## Step 6: Connect from Your Local Machine

### Configure SSH

Add to `~/.ssh/config`:

```
Include ~/.ssh/vscode-setonix_config.txt

Host setonix.pawsey.org.au
    HostName setonix.pawsey.org.au
    User <YOUR_SETONIX_USERNAME>

Host setonix
    HostName setonix.pawsey.org.au
    User <YOUR_SETONIX_USERNAME>

Host nid*
    User <YOUR_SETONIX_USERNAME>
    ProxyJump setonix
```

Then create or update `~/.ssh/vscode-setonix_config.txt`:

```
Host vscode-setonix
    HostName nid001234          # Replace with output from get-container-host.sh
    Port 9300
    User <YOUR_SETONIX_USERNAME>
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    ProxyJump setonix
```

### Connect via SSH or VS Code

**From terminal:**
```bash
ssh vscode-setonix
```

**From VS Code:**
- Install **Remote - SSH** extension
- Open command palette: `Cmd+Shift+P` → "Remote-SSH: Connect to Host..."
- Select `vscode-setonix`
- Open a folder: `$MYSOFTWARE/fakeHome`

## Important Notes

### Why You Must Customize the Dockerfile

The `Dockerfile` creates a user inside the container that matches your setonix account. This ensures:
- File permissions work correctly when the container mounts directories from setonix
- SSH correctly identifies you inside the container
- Container directories match your setonix home ownership

If you try to use someone else's pre-built image, you'll have permission issues accessing your files.

### Different Users Need Different Images

Each user must:
1. Get their own setonix UID/GID
2. Build their own Docker image with their credentials
3. Push to their own Docker Hub account
4. Pull that image to setonix

This is by design to maintain proper permissions and security.

## File Structure

| File | Purpose |
|------|---------|
| `Dockerfile` | Container definition - **must be customized** with your UID/GID/username |
| `run-container.sh` | Startup script: sets up SSH keys, writes hostname, runs container |
| `submit-container.sh` | SLURM batch script to submit container job |
| `get-container-host.sh` | Helper to retrieve compute node hostname for SSH config |

## Container Details

- **Base OS:** Ubuntu 22.04 LTS
- **SSH Port:** 9300 (inside container)
- **SSH Config:**
  - Key-based auth only
  - X11 forwarding enabled
  - PAM disabled (non-root sshd)
  - StrictModes disabled (for mounted home)
  - Root login disabled

- **User:** Your setonix username (customized per user in Dockerfile)
- **UID/GID:** Your setonix UID/GID (customized per user in Dockerfile)
- **Home:** `$MYSOFTWARE/fakeHome` (mounted from host setonix)
- **SSH Keys:** Copied to fakeHome's `.ssh/` by `run-container.sh`

## Troubleshooting

**Docker build fails**
- Ensure you updated the Dockerfile with your actual UID/GID values
- Check that username, UID, and GID are all valid (no spaces)

**SSH Connection Refused**
- Verify container is running: `squeue -u <YOUR_USERNAME>`
- Check compute node name: `bash get-container-host.sh`
- Ensure `run-container.sh` has your correct SSH public keys
- Verify SSH config points to correct hostname from `get-container-host.sh`

**Permission Denied on files**
- Ensure your Dockerfile UID/GID matches your setonix UID/GID exactly
- Rebuild and repush the image if you made changes to the Dockerfile
- Pull the new image on setonix

**Container fails to start**
- Check the SLURM output: `cat dev-container.out`
- Verify singularity module is loaded: `module list`
- Ensure sufficient memory allocated in `submit-container.sh`
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
docker buildx build --platform linux/amd64 --push -t <DOCKER_HUB_USERNAME>/vscode-setonix:latest .
```

### Run Longer Jobs

Modify `submit-container.sh`:

```bash
#SBATCH --time=24:00:00  # 24 hours
```

### Use Different Allocation

Modify `submit-container.sh`:

```bash
#SBATCH --account=$PAWSEY_PROJECT  # Uses environment variable set on setonix
```

## Project Info

- **GitHub:** https://github.com/cbottrell/vscode-setonix
- **Docker Hub:** https://hub.docker.com/r/<YOUR_DOCKER_HUB_USERNAME>/vscode-setonix
- **Base Image:** Ubuntu 22.04 LTS
- **SSH Port:** 9300

## Customization Checklist

Before first use, ensure you have:

- [ ] Updated Dockerfile with your username/UID/GID
- [ ] Updated `run-container.sh` with your public SSH keys
- [ ] Built and pushed container to your Docker Hub account
- [ ] Updated SSH config files with your username
- [ ] Set environment variables: `MYSOFTWARE` and `PAWSEY_PROJECT`
