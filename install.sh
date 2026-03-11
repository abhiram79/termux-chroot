#!/bin/bash

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print colored messages
print_msg() {
    echo -e "${1}${2}${NC}"
}

# Update and install required packages
print_msg "$YELLOW" "Updating package list and installing required repositories..."
pkg update && pkg install x11-repo root-repo && pkg install termux-x11-nightly sudo pulseaudio
if [ $? -ne 0 ]; then
    print_msg "$RED" "Error during installation, exiting script."
    exit 1
fi

print_msg "$GREEN" "Installation successful."

# Switch to superuser
su

# Create directories and download Ubuntu base
print_msg "$BLUE" "Setting up Ubuntu environment..."
mkdir -p /data/local/tmp/chrootubuntu
cd /data/local/tmp/chrootubuntu

curl https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz -o ubuntu.tar.gz
if [ $? -ne 0 ]; then
    print_msg "$RED" "Error downloading Ubuntu base, exiting script."
    exit 1
fi

tar xpvf ubuntu.tar.gz --numeric-owner
mkdir -p /sdcard
print_msg "$GREEN" "Ubuntu environment setup complete."

# Create and configure start_ubuntu.sh
print_msg "$YELLOW" "Creating start_ubuntu.sh script..."

cat <<EOL > /data/local/tmp/start_ubuntu.sh
#!/bin/sh

# The path of Ubuntu rootfs
UBUNTUPATH="/data/local/tmp/chrootubuntu"

# Fix setuid issue
busybox mount -o remount,dev,suid /data

busybox mount --bind /dev \$UBUNTUPATH/dev
busybox mount --bind /sys \$UBUNTUPATH/sys
busybox mount --bind /proc \$UBUNTUPATH/proc
busybox mount -t devpts devpts \$UBUNTUPATH/dev/pts

# /dev/shm for Electron apps
mkdir -p \$UBUNTUPATH/dev/shm
busybox mount -t tmpfs -o size=256M tmpfs \$UBUNTUPATH/dev/shm

# Mount sdcard
busybox mount --bind /sdcard \$UBUNTUPATH/sdcard

# chroot into Ubuntu
busybox chroot \$UBUNTUPATH /bin/su - root
EOL

chmod +x /data/local/tmp/start_ubuntu.sh
print_msg "$GREEN" "start_ubuntu.sh script created and made executable."

# Run the script
print_msg "$BLUE" "Running start_ubuntu.sh..."
sh /data/local/tmp/start_ubuntu.sh
if [ $? -ne 0 ]; then
    print_msg "$RED" "Error during Ubuntu chroot setup."
    exit 1
fi

# Prompt user for username and password
read -p "Enter username: " USERNAME
read -sp "Enter password: " PASSWORD
echo ""

# Inside chroot, set up networking and users
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "127.0.0.1 localhost" > /etc/hosts

groupadd -g 3003 aid_inet
groupadd -g 3004 aid_net_raw
groupadd -g 1003 aid_graphics
usermod -g 3003 -G 3003,3004 -a _apt
usermod -G 3003 -a root

print_msg "$YELLOW" "Updating and upgrading Ubuntu packages..."
apt update && apt upgrade -y

print_msg "$YELLOW" "Installing necessary packages..."
apt install -y nano vim net-tools sudo git
if [ $? -ne 0 ]; then
    print_msg "$RED" "Error during package installation."
    exit 1
fi

print_msg "$GREEN" "Packages installed successfully."

# Reconfigure timezone
dpkg-reconfigure tzdata

# Create groups and users
groupadd storage
groupadd wheel
useradd -m -g users -G wheel,audio,video,storage,aid_inet -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Grant sudo privileges
echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Switch to the created user
su - $USERNAME

# Install locales
sudo apt install -y locales
sudo locale-gen en_US.UTF-8

print_msg "$GREEN" "Ubuntu setup completed successfully!"
