#!/bin/bash
#SBATCH --account=pawsey1149
#SBATCH --partition=work
#SBATCH --job-name=dev-container
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00
#SBATCH --output=%x.out

echo "========================================"
echo "Starting VS Code Container on setonix"
echo "========================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Time: $(date)"
echo ""

echo "Loading Singularity module..."
module load singularity/4.1.0-nompi
echo "Singularity version: $(singularity --version)"
echo ""

echo "Navigating to container directory..."
cd $MYSOFTWARE/singularity/vscode-setonix
echo "Working directory: $(pwd)"
echo ""

echo "Starting container with SSH server..."
bash run-container.sh
echo ""

echo "Container is running. Job will remain active for the duration of the allocation."
echo "To connect, run: bash get-container-host.sh"
echo "========================================"
echo ""

# Keep the job alive
sleep infinity
