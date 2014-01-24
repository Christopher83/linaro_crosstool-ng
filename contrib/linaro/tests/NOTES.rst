./linaro-media-create --image-file beagle.img --dev beagle --rootfs ext4 --hwpack ~/Downloads/hwpack_linaro-omap3_20111122-1_armel_supported.tar.gz --image-size 2G --binary ~/Downloads/linaro-o-developer-tar-20111121-0.tar.gz  --hwpack-force-yes

~/opt/qemu-linaro/bin/qemu-system-arm -M beaglexm -drive if=sd,cache=writeback,file=./beagle.img -clock unix -device usb-kbd -device usb-mouse -usb -device usb-net,netdev=mynet -netdev user,id=mynet,hostfwd=tcp::7024-:22 -nographic

sudo apt-get install jed rsync openssh-server

~/.ssh/config:

Host leb
    Port 7024
    Hostname localhost
