ROOTFS='https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/aarch64/alpine-minirootfs-3.17.3-aarch64.tar.gz'
# --- NETBOOT INITRAMFS ---
mkdir -pv work/initramfs-netboot
cd work
curl -sL "$ROOTFS" | tar -xzC initramfs-netboot
mount -vo bind /dev initramfs-netboot/dev
mount -vt sysfs sysfs initramfs-netboot/sys
mount -vt proc proc initramfs-netboot/proc
cp /etc/resolv.conf initramfs-netboot/etc
cat << ! > initramfs-netboot/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

sleep 2
echo "MineekLinux: Copying qemu-aarch64-static to initramfs-netboot"
cp -v /usr/bin/qemu-aarch64-static initramfs-netboot/usr/bin
echo "MineekLinux: Installing Alpine Linux packages"
cat << ! | chroot initramfs-netboot /usr/bin/env PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin /bin/sh
apk update
apk upgrade
apk add bash alpine-base udev unudhcpd busybox-extras
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
!

sleep 2
rm -v initramfs-netboot/init
cp -v ../init/init-netboot initramfs-netboot/init
chmod +x initramfs-netboot/init
umount -v initramfs-netboot/dev
umount -v initramfs-netboot/sys
umount -v initramfs-netboot/proc

cd initramfs-netboot
sh -c "find . | cpio  --quiet -o -H newc | gzip -9 > ../initramfs-netboot.cpio.gz"
cd ..
rm -rvf initramfs-netboot
echo "MineekLinux: Done, copying initramfs-netboot.cpio.gz to output directory"
rm -v ../output/ramdisk-netboot.cpio.gz || true
cp -v initramfs-netboot.cpio.gz ../output/ramdisk-netboot.cpio.gz
echo "MineekLinux: Done, cleaning up"
cd ..
rm -rvf work
echo "MineekLinux: Alright, now we're going to build the real rootfs"

# --- REAL ROOTFS ---
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
# rm -v rootfs/init
# cp -v ../init/init rootfs/init
# chmod +x rootfs/init
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
    Option       "Device" "/dev/hx-touch"
EndSection
!

cat << ! > rootfs/usr/bin/setup_xfce
#!/bin/sh
echo "This will install xfce4 and configure it for the iPhone"
echo "This will take a while, please be patient"
apk update
apk add xfce4 dbus xorg-server xf86-video-fbdev xf86-input-evdev
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

chmod +x rootfs/usr/bin/enable_usb_networking
chmod +x rootfs/usr/bin/setup_xfce

cp -v ../copybins/hx-touchd rootfs/usr/bin
chmod +x rootfs/usr/bin/hx-touchd

cd rootfs
# create a ext4 filesystem image of size 5GB
dd if=/dev/zero of=../rootfs.img bs=1M count=5120
mkfs.ext4 ../rootfs.img
cd ..
mkdir -pv rootfs-mount
mount -v rootfs.img rootfs-mount
cp -av rootfs/* rootfs-mount
umount -v rootfs-mount
rm -rvf rootfs-mount
echo "MineekLinux: Done, copying rootfs.img to output directory"
rm -v ../output/rootfs.img || true
cp -v rootfs.img ../output/rootfs.img
echo "MineekLinux: Done, cleaning up"
cd ..
rm -rvf work
echo "MineekLinux: Done!"