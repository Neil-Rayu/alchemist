#!/bin/ash
mkdir -p /mnt/data
mount /dev/sr1 /mnt/data
cp /mnt/data/myapp /root/
chmod +x /root/myapp
echo "✅ Setup complete! Run with: ./myapp"
