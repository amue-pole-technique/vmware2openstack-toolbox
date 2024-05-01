#!/bin/bash

SCRIPT_DIR=$( dirname $0)

SYSTEM_MOUNT_DIR=$1

if [ -z "$SYSTEM_MOUNT_DIR" ]; then echo "syntax: $( basename $0 ) /dir/to/mounted/system/part"; exit 1; fi
if [ ! -d "$SYSTEM_MOUNT_DIR" ]; then echo "Error: directory '$SYSTEM_MOUNT_DIR' not found"; exit 1; fi
if [ "$SYSTEM_MOUNT_DIR" == "/" ]; then echo "Error: cannot target the directory $SYSTEM_MOUNT_DIR"; exit 1; fi

TARGET=$SYSTEM_MOUNT_DIR/etc/fstab
if [ -f "$TARGET" ]; then
	echo "Cleanup: fstab"
	# Notice: this change must go in pair with the following openstack settings on the system drive
	#  --image-property hw_disk_bus=scsi  --image-property hw_scsi_model=virtio-scsi
	sed -i 's#^/dev/vd#/dev/sd#g' $TARGET

	# remove any NFS mount
	sed -i -e '/.*:.* nfs[34]* / s/^#*/#/' $TARGET

fi

TARGET=$SYSTEM_MOUNT_DIR/etc/sysconfig/network-scripts
if [ -d "$TARGET" ]; then
	echo "Cleanup: network-scripts configuration ..."
	cd "$TARGET"  || exit 1
	mkdir -p bak
	if compgen -G "route-*" &>/dev/null; then mv route-* bak/ ; fi
	# must filter to keep ifcfg-lo in place
	if compgen -G "ifcfg-e*" &>/dev/null; then mv ifcfg-e* bak/ ; fi

	# default dhcp configuration for eth0
	echo "BOOTPROTO=dhcp
DEVICE=eth0
ONBOOT=yes" > ifcfg-eth0

	TARGET=$SYSTEM_MOUNT_DIR/etc/sysconfig/network
	# remove any gateway information from network
	sed -i '/^GATEWAYDEV=.*/d' $TARGET
	sed -i '/^GATEWAY=.*/d' $TARGET
fi

TARGET=$SYSTEM_MOUNT_DIR/etc/xinetd.d
if [ -d "$TARGET" ] && [ -f "$SYSTEM_MOUNT_DIR/etc/hosts.allow" ]; then
	echo "Cleanup: xinetd ..."
	rm $SYSTEM_MOUNT_DIR/etc/hosts.deny
	rm $SYSTEM_MOUNT_DIR/etc/hosts.allow
	rm $TARGET/sshd-*

	# sshd service started by xinetd - reactivated in systemd
	TARGET=$SYSTEM_MOUNT_DIR/etc/systemd/system/multi-user.target.wants
	if [ -d "$TARGET" ] && [ -f $SYSTEM_MOUNT_DIR/usr/lib/systemd/system/sshd.service ]; then
		# the source might not exist, but the link will still be created
		ln -sf  /usr/lib/systemd/system/sshd.service   $TARGET/
	fi
fi

TARGET=$SYSTEM_MOUNT_DIR/etc/ssh/sshd_config
if [ -f "$TARGET" ]; then
	echo "Cleanup: sshd listen configuration ..."

	# change only the first occurence
	sed -i '0,/ListenAddress/{s/^ListenAddress .*/MODListenAddress 0.0.0.0/}'  $TARGET
	# delete all other listenaddress
	sed -i '/^ListenAddress .*/d'  $TARGET
	# fix the remaining occurence
	sed -i 's/^MODListenAddress /ListenAddress /'  $TARGET
fi

TARGET=$SYSTEM_MOUNT_DIR/etc/hosts
if [ -f "$TARGET" ]; then
	echo "Cleanup: hosts file ..."

	THISSERVER=$( cat `dirname $TARGET`/hostname )

	echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > $TARGET
	echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> $TARGET
fi


cd "${SCRIPT_DIR}"
echo "Cleanup completed"
