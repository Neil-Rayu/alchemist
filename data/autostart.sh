#!/bin/ash
echo "🚀 Auto-starting Go application..."
mkdir -p /mnt/data
mount /dev/sr1 /mnt/data
cp /mnt/data/myapp /root/
chmod +x /root/myapp
echo "✅ Running your Go program:"
/root/myapp
echo "💡 Program finished. You're now in Alpine Linux shell."
