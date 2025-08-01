#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 Building Go binary for Linux...${NC}"
GOOS=linux GOARCH=amd64 go build -o myapp main.go

echo -e "${BLUE}📦 Creating data ISO with your binary...${NC}"
mkdir -p data
cp myapp data/

# Create startup script that runs automatically
cat > data/autorun.sh << 'EOF'
#!/bin/ash
echo "Auto-setting up your Go binary..."
mkdir -p /mnt/data
mount /dev/sr1 /mnt/data 2>/dev/null || echo "Data already mounted"
cp /mnt/data/myapp /root/ 2>/dev/null || echo "Binary already copied"
chmod +x /root/myapp
echo "Your binary is ready at: /root/myapp"
echo "Run it with: ./myapp"
echo "To re-run setup: /mnt/data/autorun.sh"
EOF

chmod +x data/autorun.sh

# Create manual setup script for reference
cat > data/setup.sh << 'EOF'
#!/bin/ash
mkdir -p /mnt/data
mount /dev/sr1 /mnt/data
cp /mnt/data/myapp /root/
chmod +x /root/myapp
echo "✅ Setup complete! Run with: ./myapp"
EOF

chmod +x data/setup.sh

# Create ISO
if command -v genisoimage > /dev/null; then
    genisoimage -o data.iso -r data/ > /dev/null 2>&1
elif command -v mkisofs > /dev/null; then
    mkisofs -o data.iso -r data/ > /dev/null 2>&1
else
    echo -e "${RED}❌ Need genisoimage or mkisofs. Install with: brew install cdrtools${NC}"
    exit 1
fi

# Download Alpine if not present
if [ ! -f alpine-standard.iso ]; then
    echo -e "${BLUE}Downloading Alpine Linux ISO...${NC}"
    wget -q https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso -O alpine-standard.iso
fi

echo -e "${GREEN}🚀 Starting Alpine Linux with your Go binary...${NC}"
echo ""
echo -e "${YELLOW}📋 QUICK SETUP IN ALPINE:${NC}"
echo -e "   ${GREEN}Login as: root${NC} (no password)"
echo -e "   ${GREEN}Run: /mnt/data/autorun.sh${NC} (auto-setup)"
echo -e "   ${GREEN}Then: ./myapp${NC} (run your program)"
echo ""
echo -e "${YELLOW}💡 Manual commands if needed:${NC}"
echo "   mkdir /mnt/data && mount /dev/sr1 /mnt/data"
echo "   cp /mnt/data/myapp /root/ && chmod +x /root/myapp"
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
  -drive file=data.iso,format=raw,media=cdrom \
  -boot d