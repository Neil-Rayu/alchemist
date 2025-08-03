#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building Go binary for Linux...${NC}"
GOOS=linux GOARCH=amd64 go build -o myapp main.go

# Create shared directory if it doesn't exist
mkdir -p shared
cp myapp shared/

# Download Alpine minirootfs to shared folder if not present
if [ ! -f shared/alpine-minirootfs-3.22.0-x86_64.tar.gz ]; then
    echo -e "${BLUE}Downloading Alpine minirootfs to shared folder...${NC}"
    curl -L -o shared/alpine-minirootfs-3.22.0-x86_64.tar.gz "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz"
fi

# Create simple setup script for Alpine minirootfs
cat > shared/setup-minifs.sh << 'EOF'
#!/bin/sh

set -e

# Colors for Alpine
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Create Alpine minirootfs
MINIFS_DIR="/tmp/alpine-minifs"

print_step "Setting up Alpine minirootfs..."

# Use pre-downloaded Alpine minirootfs from shared folder
cd /tmp
if [ ! -f "alpine-minirootfs-3.22.0-x86_64.tar.gz" ]; then
    if [ -f "/shared/alpine-minirootfs-3.22.0-x86_64.tar.gz" ]; then
        print_step "Copying Alpine minirootfs from shared folder..."
        cp /shared/alpine-minirootfs-3.22.0-x86_64.tar.gz .
    else
        echo -e "${RED}Error: alpine-minirootfs-3.22.0-x86_64.tar.gz not found in /shared/${NC}"
        exit 1
    fi
fi

# Extract to minifs directory
if [ -d "$MINIFS_DIR" ]; then
    print_step "Removing existing minifs..."
    rm -rf "$MINIFS_DIR"
fi

mkdir -p "$MINIFS_DIR"
print_step "Extracting Alpine minirootfs..."
tar -xzf "alpine-minirootfs-3.22.0-x86_64.tar.gz" -C "$MINIFS_DIR"

# Set up cgroups support
print_step "Setting up cgroups..."

# Create cgroup mount points
mkdir -p "$MINIFS_DIR/sys/fs/cgroup"
mkdir -p "$MINIFS_DIR/sys/fs/cgroup/pids"
mkdir -p "$MINIFS_DIR/sys/fs/cgroup/memory"
mkdir -p "$MINIFS_DIR/sys/fs/cgroup/cpu"
mkdir -p "$MINIFS_DIR/sys/fs/cgroup/cpuset"

# Create a simple init script that sets up cgroups
cat > "$MINIFS_DIR/sbin/setup-cgroups" << 'CGROUP_EOF'
#!/bin/sh

# Mount cgroup filesystem if not already mounted
if ! mountpoint -q /sys/fs/cgroup 2>/dev/null; then
    mount -t tmpfs cgroup_root /sys/fs/cgroup
fi

# Mount individual cgroup controllers
mount -t cgroup -o pids cgroup /sys/fs/cgroup/pids 2>/dev/null || true
mount -t cgroup -o memory cgroup /sys/fs/cgroup/memory 2>/dev/null || true
mount -t cgroup -o cpu cgroup /sys/fs/cgroup/cpu 2>/dev/null || true
mount -t cgroup -o cpuset cgroup /sys/fs/cgroup/cpuset 2>/dev/null || true

echo "Cgroups mounted successfully"
echo "Available controllers:"
cat /proc/cgroups 2>/dev/null || echo "No cgroups info available"

# Create a test cgroup for demonstration
if [ -d "/sys/fs/cgroup/pids" ]; then
    mkdir -p /sys/fs/cgroup/pids/alchemist
    # Set max processes to 10 for demo
    echo 10 > /sys/fs/cgroup/pids/alchemist/pids.max
    echo "Created test cgroup: /sys/fs/cgroup/pids/alchemist"
    echo "Max PIDs set to: $(cat /sys/fs/cgroup/pids/alchemist/pids.max)"
fi
CGROUP_EOF

chmod +x "$MINIFS_DIR/sbin/setup-cgroups"

# Create a container init script that sets up everything
cat > "$MINIFS_DIR/sbin/container-init" << 'INIT_EOF'
#!/bin/sh

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

# Set up cgroups
/sbin/setup-cgroups

# Set up environment
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

echo "Container initialized with cgroups support"
echo ""
echo "Cgroup usage examples:"
echo "  # Limit processes in a cgroup:"
echo "  mkdir /sys/fs/cgroup/pids/alchemist"
echo "  echo 5 > /sys/fs/cgroup/pids/alchemist/pids.max"
echo "  echo \$\$ > /sys/fs/cgroup/pids/alchemist/cgroup.procs"
echo ""
echo "  # Limit memory:"
echo "  mkdir /sys/fs/cgroup/memory/alchemist"
echo "  echo 100M > /sys/fs/cgroup/memory/alchemist/memory.limit_in_bytes"
echo "  echo \$\$ > /sys/fs/cgroup/memory/alchemist/cgroup.procs"
echo ""

# Run command or shell
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec /bin/sh
fi
INIT_EOF

chmod +x "$MINIFS_DIR/sbin/container-init"

# Copy your app if it exists
if [ -f "/shared/myapp" ]; then
    cp /shared/myapp "$MINIFS_DIR/usr/local/bin/"
    chmod +x "$MINIFS_DIR/usr/local/bin/myapp"
    print_success "Copied myapp to minifs"
fi

print_success "Alpine minirootfs created at $MINIFS_DIR with cgroups support"
print_step "Enter with cgroups enabled:"
echo "  chroot $MINIFS_DIR /sbin/container-init"
echo ""
print_step "Example cgroup usage after entering:"
echo "  # Create and use a PID-limited cgroup:"
echo "  mkdir /sys/fs/cgroup/pids/alchemist"
echo "  echo 3 > /sys/fs/cgroup/pids/alchemist/pids.max"
echo "  echo \$\$ > /sys/fs/cgroup/pids/alchemist/cgroup.procs"
echo "  # Now try: for i in \$(seq 1 10); do sleep 60 & done"
echo ""
print_step "Test memory limits:"
echo "  mkdir /sys/fs/cgroup/memory/alchemist"
echo "  echo 50M > /sys/fs/cgroup/memory/alchemist/memory.limit_in_bytes"
echo "  echo \$\$ > /sys/fs/cgroup/memory/alchemist/cgroup.procs"

EOF

chmod +x shared/setup-minifs.sh

# Download Alpine if not present
if [ ! -f alpine-standard.iso ]; then
    echo -e "${BLUE}Downloading Alpine Linux ISO...${NC}"
    curl -L -o alpine-standard.iso "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso"
fi

echo -e "${GREEN}Starting Alpine Linux with shared folder...${NC}"
echo ""
echo -e "${YELLOW}SETUP INSTRUCTIONS:${NC}"
echo -e "   ${GREEN}1. Login as: root${NC} (no password)"
echo -e "   ${GREEN}2. Mount shared folder: mkdir /shared && mount -t 9p -o trans=virtio shared /shared${NC}"
echo -e "   ${GREEN}3. Setup minirootfs: /shared/setup-minifs.sh${NC}"
echo -e "   ${GREEN}4. Enter minifs: chroot /tmp/alpine-minifs /bin/sh${NC}"
echo ""
echo -e "${YELLOW}One-liner setup:${NC}"
echo "   mkdir /shared && mount -t 9p -o trans=virtio shared /shared && /shared/setup-minifs.sh"
echo ""
echo -e "${BLUE}Press Ctrl+A then X to exit QEMU${NC}"
echo ""

qemu-system-x86_64 \
  -m 1024 \
  -smp 2 \
  -nographic \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -drive file=alpine-standard.iso,format=raw,media=cdrom \
  -virtfs local,path=./shared,mount_tag=shared,security_model=passthrough \
  -boot d