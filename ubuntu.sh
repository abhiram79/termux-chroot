#!/bin/sh

# Ubuntu rootfs path
UBUNTUPATH="/data/local/tmp/chrootubuntu"

# setup chroot environment 
busybox mount -o remount,dev,suid /data
busybox mount --bind /dev $UBUNTUPATH/dev
busybox mount --bind /sys $UBUNTUPATH/sys
busybox mount --bind /proc $UBUNTUPATH/proc
busybox mount -t devpts devpts $UBUNTUPATH/dev/pts
mkdir -p $UBUNTUPATH/dev/shm
busybox mount -t tmpfs -o size=256M tmpfs $UBUNTUPATH/dev/shm

# Mount Device Storage 
busybox mount --bind /sdcard $UBUNTUPATH/sdcard

# chroot into Ubuntu as root
busybox chroot $UBUNTUPATH /bin/su - root

# example for signing as user
# busybox chroot $UBUNTUPATH /bin/su - username
