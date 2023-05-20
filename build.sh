ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/aarch64/alpine-minirootfs-3.17.3-aarch64.tar.gz'
umount -v work/rootfs/{dev,sys,proc} >/dev/null 2>&1
rm -rf work
mkdir -pv work/rootfs
cd work
curl -sL "$ROOTFS" | tar -xzC rootfs
mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc

cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

sleep 2
echo "MineekLinux: Copying qemu-aarch64-static to rootfs"
cp -v /usr/bin/qemu-aarch64-static rootfs/usr/bin
echo "MineekLinux: Installing Alpine Linux packages"

cat << ! | chroot rootfs /usr/bin/env PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin /bin/sh
apk update
apk upgrade
apk add bash alpine-base udev unudhcpd busybox-extras
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

sleep 2
rm -v rootfs/init
cp -v ../init/init rootfs/init
chmod +x rootfs/init
umount -v rootfs/dev
umount -v rootfs/sys
umount -v rootfs/proc

# make a usr/bin/setup_xfce script
cat << ! > rootfs/usr/bin/setup_xfce_data_screen.conf
Section "ServerLayout"
    Identifier "Layout0"
    Screen "Screen0"
    InputDevice "touchscreen" "Pointer"
EndSection
Section "Device"
    Identifier "Card0"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
EndSection
Section "Screen"
    Identifier "Screen0"
    Device "Card0"
    DefaultDepth 24
    SubSection "Display"
        Depth 32
    EndSubSection
EndSection
Section "ServerFlags"
    Option "Pixmap" "24"
EndSection
!

cat << ! > rootfs/usr/bin/setup_xfce_data_touchscreen.conf
Section "InputDevice"
    Driver       "evdev"
    Identifier   "touchscreen"
    Option       "Device" "/dev/input/event1"
EndSection
!

cat << ! > rootfs/usr/bin/setup_xfce
#!/bin/sh
echo "This will install xfce4 and configure it for the iPhone"
echo "This will take a while, please be patient"
apk update
apk add xfce4 dbus xorg-server xf86-video-fbdev
rc-service dbus start
cp /usr/bin/setup_xfce_data_screen.conf /usr/share/X11/xorg.conf.d/screen.conf
cp /usr/bin/setup_xfce_data_touchscreen.conf /usr/share/X11/xorg.conf.d/touchscreen.conf
echo "Now you can run startxfce4 to start the desktop environment"
!

cat << ! > rootfs/usr/bin/enable_usb_networking
#!/bin/sh
ip route add default via 172.16.42.2 dev usb0
echo nameserver 1.1.1.1 > /etc/resolv.conf
!

cp -v ../copybins/hx-touchd rootfs/usr/bin

cd rootfs
sh -c "find . | cpio  --quiet -o -H newc | gzip -9 > ../initramfs.cpio.gz"
cd ..
rm -rvf rootfs
echo "MineekLinux: Done, copying initramfs.cpio.gz to output directory"
rm -v ../output/ramdisk.cpio.gz || true
cp -v initramfs.cpio.gz ../output/ramdisk.cpio.gz
echo "MineekLinux: Done, cleaning up"
cd ..
rm -rvf work
echo "MineekLinux: Alright, we're done here, goodbye!"