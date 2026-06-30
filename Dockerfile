FROM quay.io/jupyter/minimal-notebook:x86_64-python-3.13

USER root

# Install SSH
RUN apt-get update && apt-get install -y openssh-server && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config && \
    sed -i 's/#Port 22/Port 9300/' /etc/ssh/sshd_config && \
    sed -i 's/#StrictModes yes/StrictModes no/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Create SSH privilege separation directory and generate SSH host keys
RUN mkdir -p /run/sshd && \
    ssh-keygen -A && \
    chmod 644 /etc/ssh/ssh_host_*_key*

# Create user with matching host UID/GID
# IMPORTANT: Replace USERNAME, UID, and GID with your values from setonix
# Get your values: id <username>
# Example: RUN groupadd -g 1000 myuser && useradd -m -u 1000 -g 1000 -s /bin/bash myuser
RUN groupadd -g 25420 bottrell && \
    useradd -m -u 25420 -g 25420 -s /bin/bash bottrell

# Install Python packages
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Start SSH
CMD ["/usr/sbin/sshd", "-D"]
