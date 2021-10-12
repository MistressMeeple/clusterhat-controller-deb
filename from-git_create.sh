# Should we use qemu to modify the images
# On Ubuntu this can be used after running
# "apt install qemu-user kpartx qemu-user-static"
QEMU=0
MACHINE=`uname -m`
if ! [ "$MACHINE" = "armv7l" -o "$MACHINE" = "aarch64" ] ;then
	if [ -f "/usr/bin/qemu-arm-static" ];then
		QEMU=1
	else 
		echo 'Unable to run as we're not running on ARM and we don't have "/usr/bin/qemu-arm-static"'
		exit
	fi
fi

# Make sure we have git and zerofree
which git >/dev/null 2>&1
if [ $? -eq 1 ];then
	echo "Installing git"
	apt install -y git
fi
which zerofree >/dev/null 2>&1
if [ $? -eq 1 ];then
	echo "Installing zerofree"
	apt install -y zerofree
fi

# Loop each image type
for BUILD in "${SOURCES[@]}"; do
	# Extract '|' separated variables
	IFS='|' read -ra IMAGE <<< "$BUILD"
	SOURCEFILENAME=${IMAGE[0]}
	DESTFILENAME=${IMAGE[1]}
	VARNAME=${IMAGE[2]}
	RELEASE=${IMAGE[3]}
	
	# Create the bridged controller

	if [ -f "$DEST/$DESTFILENAME-CBRIDGE.img" ];then
		echo "Skipping $TYPENAME build"
		echo " $DEST/$DESTFILENAME-CBRIDGE.img exists"
	else
		echo "Building $TYPENAME"
		echo " Copying source image"
		cp "$SOURCE/$SOURCEFILENAME" "$DEST/$DESTFILENAME-CBRIDGE.img"

		

		mount -o noatime,nodiratime ${LOOP}p2 $MNT
		mount ${LOOP}p1 $MNT/boot
		mount -o bind /proc $MNT/proc
		mount -o bind /dev $MNT/dev

		if [ $QEMU -eq 1 ];then
			cp /usr/bin/qemu-arm-static $MNT/usr/bin/qemu-arm-static
			sed -i "s/\(.*\)/#\1/" $MNT/etc/ld.so.preload
		fi

		chroot $MNT apt -y purge wolfram-engine

		chroot $MNT apt update -y
		chroot $MNT /bin/bash -c 'APT_LISTCHANGES_FRONTEND=none apt -y dist-upgrade'

		chroot $MNT apt -y install rpiboot bridge-utils wiringpi screen minicom python-smbus subversion git libusb-1.0-0-dev nfs-kernel-server python-usb python-libusb1 busybox initramfs-tools-core

		# Setup ready for iptables for NAT for NAT/WiFi use
		# Preseed answers for iptables-persistent install
		chroot $MNT /bin/bash -c "echo 'iptables-persistent iptables-persistent/autosave_v4 boolean false' | debconf-set-selections"
		chroot $MNT /bin/bash -c "echo 'iptables-persistent iptables-persistent/autosave_v6 boolean false' | debconf-set-selections"

		chroot $MNT /bin/bash -c 'APT_LISTCHANGES_FRONTEND=none apt -y install iptables-persistent'


		## append
		echo '#net.ipv4.ip_forward=1 # ClusterCTRL' >> $MNT/etc/sysctl.conf
		
		## prebaked
		$MNT/etc/iptables/rules.v4

		# prebaked
		$MNT/etc/dhcpcd.conf

		# Enable uart with login
		chroot $MNT /bin/bash -c "raspi-config nonint do_serial 0"

		# Enable I2C (used for I/O expander on Cluster HAT v2.x)
		chroot $MNT /bin/bash -c "raspi-config nonint do_i2c 0"


		echo -e "mountd: 172.19.180.\nrpcbind: 172.19.180.\n" >> $MNT/etc/hosts.allow
		echo -e "mountd: ALL\nrpcbind: ALL\n" >> $MNT/etc/hosts.deny

		# Extract files
		(tar --exclude=.git -cC ../files/ -f - .) | (chroot $MNT tar -xC /)

		# Disable the auto filesystem resize and convert to bridged controller
		sed -i "s# init=.*# init=/usr/sbin/reconfig-clusterctrl cbridge#" $MNT/boot/cmdline.txt

		# Setup directories for rpiboot
		mkdir -p $MNT/var/lib/clusterctrl/boot
		mkdir $MNT/var/lib/clusterctrl/nfs
		ln -fs /boot/bootcode.bin $MNT/var/lib/clusterctrl/boot/


		# Enable clusterctrl init
		chroot $MNT systemctl enable clusterctrl-init

		# Enable rpiboot for booting without SD cards
		chroot $MNT systemctl enable clusterctrl-rpiboot

		# Disable nfs server (rely on clusterctrl-rpiboot to start it if needed)
		chroot $MNT systemctl disable nfs-kernel-server

		# Setup NFS exports for NFSROOT
		for ((P=1;P<=4;P++));do
			echo "/var/lib/clusterctrl/nfs/p$P 172.19.180.$P(rw,sync,no_subtree_check,no_root_squash)" >> $MNT/etc/exports
			mkdir "$MNT/var/lib/clusterctrl/nfs/p$P"
		done

		# Setup config.txt file
		C=`grep -c "dtoverlay=dwc2,dr_mode=peripheral" $MNT/boot/config.txt`
		if [ $C -eq 0  ];then
			echo -e "# Load overlay to allow USB Gadget devices\n#dtoverlay=dwc2,dr_mode=peripheral" >> $MNT/boot/config.txt
		fi

		rm -f $MNT/etc/ssh/*key*
		chroot $MNT apt -y autoremove --purge
		chroot $MNT apt clean

		if [ $QEMU -eq 1 ];then
			rm $MNT/usr/bin/qemu-arm-static
			sed -i "s/^#//" $MNT/etc/ld.so.preload
		fi

		umount $MNT/dev
		umount $MNT/proc
		umount $MNT/boot
		umount $MNT

		zerofree -v ${LOOP}p2
		sleep 5

		losetup -d $LOOP
	fi
	
		
done
