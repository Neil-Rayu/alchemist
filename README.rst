======================================
Automated Alpine QEMU Development Setup
======================================

Quick Command Reference
======================================

.. code-block:: bash

  # Shared directory for your Go binary
  mkdir /shared && mount -t 9p -o trans=virtio shared /shared
  # Your binary is at: /shared/myapp

  # OUTDATED: Mounting data ISO
  mkdir /mnt/data && mount /dev/sr1 /mnt/data
  /mnt/data/autorun.sh


======================================


Quick Start
===========

This setup allows you to develop Go applications and test them in an isolated Alpine Linux environment using QEMU.

Prerequisites
-------------

.. code-block:: bash

   # Install required tools on macOS
   brew install qemu cdrtools

   #install Go if not already installed
   brew install go

   #Install alpine ISO
   wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso --O alpine-standard.iso   

Directory Structure
-------------------

::

  your-project/
  ├── main.go               # Your Go source
  ├── runner.sh             # Start Alpine with shared folder
  ├── build.sh              # Quick build script
  ├── shared/               # Shared folder with host
  │   └── myapp             # Your Linux binary (auto-generated)
  └── alpine-standard.iso   # Alpine ISO


Main Script: runner.sh
===========================

Create this script to automate everything:

.. code-block:: bash

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
    
Development Workflow
====================

1. Initial Setup
----------------

.. code-block:: bash

   # Make script executable
   chmod +x runner.sh

   # First run
   ./runner.sh

2. In Alpine Terminal
---------------------

.. code-block:: bash

   # Login
   root

   # Mount data ISO
   mkdir /shared && mount -t 9p -o trans=virtio shared /shared

   # Run your program
   /shared/myapp run ...

3. Development Loop
-------------------

.. code-block:: bash

   # Edit your main.go
   vim main.go

   # Test in Alpine (rebuilds automatically)
   ./build.sh

Advanced Features
=================

SSH Setup (Optional)
--------------------

If you want SSH access to your Alpine VM:

.. code-block:: bash

   # In Alpine, after autorun.sh:
   apk add openssh
   adduser -D -s /bin/ash developer
   echo "developer:dev123" | chpasswd
   rc-update add sshd default
   rc-service sshd start

   # From your Mac:
   ssh developer@localhost -p 2222

Persistent Storage
------------------

To keep changes between reboots:

.. code-block:: bash

   # In Alpine:
   setup-alpine  # Install to disk
   # Follow prompts, then reboot

Custom Environment
------------------

Add packages to your autorun.sh:

.. code-block:: bash

   # In data/autorun.sh, add:
   apk add htop curl git vim

Troubleshooting
===============

Common Issues
-------------

1. **"Permission denied" when running script**
   
   .. code-block:: bash

      chmod +x run-alpine.sh

2. **"mkisofs command not found"**
   
   .. code-block:: bash

      brew install cdrtools

3. **Binary doesn't run in Alpine**
   
   .. code-block:: bash

      # Make sure you're building for Linux:
      GOOS=linux GOARCH=amd64 go build -o myapp main.go

4. **Can't exit QEMU**
   
   .. code-block:: bash

      # Press: Ctrl+A, then X
      # Or from Alpine: poweroff

Example main.go
===============

.. code-block:: go

   package main

   import (
       "fmt"
       "os"
       "runtime"
   )

   func main() {
       fmt.Printf("Hello from Go!\n")
       fmt.Printf("OS: %s\n", runtime.GOOS)
       fmt.Printf("Arch: %s\n", runtime.GOARCH)
       fmt.Printf("Working directory: %s\n", os.Getenv("PWD"))
       
       // Your container/runtime logic here
       fmt.Println("This is where your container runtime would go!")
   }

This setup gives you a lightweight, fast development environment for testing Go programs in isolated Linux containers 0-0