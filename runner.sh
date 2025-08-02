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

# Download Alpine if not present
if [ ! -f alpine-standard.iso ]; then
    echo -e "${BLUE}Downloading Alpine Linux ISO...${NC}"
    wget -q https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso -O alpine-standard.iso
fi

echo -e "${GREEN}Starting Alpine Linux with shared folder...${NC}"
echo ""
echo -e "${YELLOW}SETUP INSTRUCTIONS:${NC}"
echo -e "   ${GREEN}1. Login as: root${NC} (no password)"
echo -e "   ${GREEN}2. Mount shared folder: mkdir /shared && mount -t 9p -o trans=virtio shared /shared${NC}"
echo -e "   ${GREEN}3. Your binary is at: /shared/myapp${NC}"
echo -e "   ${GREEN}4. Run: /shared/myapp${NC}"
echo ""
echo -e "${YELLOW}One-liner setup:${NC}"
echo "   mkdir /shared && mount -t 9p -o trans=virtio shared /shared && /shared/myapp"
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