#!/bin/ash
echo "Auto-setting up your Go binary..."
mkdir -p /mnt/data
mount /dev/sr1 /mnt/data 2>/dev/null || echo "Data already mounted"
cp /mnt/data/myapp /root/ 2>/dev/null || echo "Binary already copied"
chmod +x /root/myapp
echo "Your binary is ready at: /root/myapp"
echo "Run it with: ./myapp"
echo "To re-run setup: /mnt/data/autorun.sh"
