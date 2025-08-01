======================================
Automated Alpine QEMU Development Setup
======================================

COMMON COMMAND
======================================

.. code-block:: bash
  
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

Directory Structure
-------------------

::

   your-project/
   ├── main.go              # Your Go application
   ├── run-alpine.sh        # Main script (see below)
   ├── alpine-standard.iso  # Downloaded Alpine ISO
   ├── data.iso            # Generated data ISO with your binary
   └── data/               # Temporary directory for binary
       └── myapp           # Compiled Linux binary

Main Script: run-alpine.sh
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

   echo -e "${BLUE}Creating data ISO with your binary...${NC}"
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
   echo "Setup complete! Run with: ./myapp"
   EOF

   chmod +x data/setup.sh

   # Create ISO
   if command -v genisoimage > /dev/null; then
       genisoimage -o data.iso -r data/ > /dev/null 2>&1
   elif command -v mkisofs > /dev/null; then
       mkisofs -o data.iso -r data/ > /dev/null 2>&1
   else
       echo -e "${RED}Need genisoimage or mkisofs. Install with: brew install cdrtools${NC}"
       exit 1
   fi

   # Download Alpine if not present
   if [ ! -f alpine-standard.iso ]; then
       echo -e "${BLUE}Downloading Alpine Linux ISO...${NC}"
       wget -q https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso -O alpine-standard.iso
   fi

   echo -e "${GREEN}Starting Alpine Linux with your Go binary...${NC}"
   echo ""
   echo -e "${YELLOW}QUICK SETUP IN ALPINE:${NC}"
   echo -e "   ${GREEN}Login as: root${NC} (no password)"
   echo -e "   ${GREEN}Run: /mnt/data/autorun.sh${NC} (auto-setup)"
   echo -e "   ${GREEN}Then: ./myapp${NC} (run your program)"
   echo ""
   echo -e "${YELLOW}Manual commands if needed:${NC}"
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

Even Easier: Full Automation Script
====================================

For completely hands-off operation:

.. code-block:: bash

   #!/bin/bash
   # run-alpine-auto.sh - Fully automated version

   set -e

   echo "Building and setting up..."
   GOOS=linux GOARCH=amd64 go build -o myapp main.go

   mkdir -p data
   cp myapp data/

   # Create a script that runs your program automatically on boot
   cat > data/autostart.sh << 'EOF'
   #!/bin/ash
   echo "Auto-starting Go application..."
   mkdir -p /mnt/data
   mount /dev/sr1 /mnt/data
   cp /mnt/data/myapp /root/
   chmod +x /root/myapp
   echo "Running your Go program:"
   /root/myapp
   echo "Program finished. You're now in Alpine Linux shell."
   EOF

   chmod +x data/autostart.sh

   genisoimage -o data.iso -r data/ > /dev/null 2>&1

   # Download Alpine if needed
   [ ! -f alpine-standard.iso ] && wget -q https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso -O alpine-standard.iso

   echo "Starting Alpine - your program will run automatically after login!"
   echo "   Login as: root (no password)"
   echo "   Run: /mnt/data/autostart.sh"

   qemu-system-x86_64 \
     -m 1024 \
     -smp 2 \
     -nographic \
     -netdev user,id=net0 \
     -device virtio-net,netdev=net0 \
     -drive file=alpine-standard.iso,format=raw,media=cdrom \
     -drive file=data.iso,format=raw,media=cdrom \
     -boot d

Development Workflow
====================

1. Initial Setup
----------------

.. code-block:: bash

   # Make script executable
   chmod +x run-alpine.sh

   # First run
   ./run-alpine.sh

2. Development Loop
-------------------

.. code-block:: bash

   # Edit your main.go
   vim main.go

   # Test in Alpine (rebuilds automatically)
   ./run-alpine.sh

3. In Alpine Terminal
---------------------

.. code-block:: bash

   # Login
   root

   # Quick setup (one command)
   /mnt/data/autorun.sh

   # Run your program
   ./myapp

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

Debugging
---------

To see what's in your data ISO:

.. code-block:: bash

   # Mount the ISO on macOS to inspect
   hdiutil mount data.iso
   ls /Volumes/CDROM/
   hdiutil unmount /Volumes/CDROM/

To check if your binary is correct:

.. code-block:: bash

   file myapp  # Should show: Linux x86-64 executable

Tips
====

- **Fast iteration**: Keep Alpine running and just rebuild/remount
- **Multiple binaries**: Put multiple programs in the data/ directory
- **Configuration files**: Add config files to data/ directory too
- **Networking**: Alpine has full network access to download packages
- **File sharing**: Use the data ISO to share any files with Alpine

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

This setup gives you a lightweight, fast development environment for testing Go programs in isolated Linux containers!