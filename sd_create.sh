#!/bin/bash

if ! [ $# -eq 0 ]; then
	if ! [ -z "$1" ]; then
		SD_CARD_DEV=$1
	fi

	if ! [ -z "$2" ]; then
		SD_CARD_IMG=$2
	fi
fi

# Check if the card device variable has been set
if [ -z "$SD_CARD_DEV" ]; then
	echo "[ERROR]: SD_CARD_DEV is unset"
	exit
elif [ -z "$SD_CARD_IMG" ]; then
	echo "[ERROR]: SD_CARD_IMG is unset"
	exit
fi

# Check if the card device has mounted partitions
if [ $(mount | grep -c "${SD_CARD_DEV}[0-9]*") != "0" ]; then
	echo "SD card has mounted partitions -> unmounting"
	mount | grep -o "${SD_CARD_DEV}[0-9]*" | xargs umount -n

	if [ $? -ne 0 ]; then
		echo "[ERROR]: Failed to unmount existing partitions"
		exit
	fi

	sleep 3
fi

# Create a new partition table for the card
parted ${SD_CARD_DEV} --script -- mklabel msdos \
		mkpart primary fat32 1MiB 128MiB \
		mkpart primary ext4 128MiB 100%

sleep 3

bootp=${SD_CARD_DEV}1
rootfsp=${SD_CARD_DEV}2

mkfs.vfat -n BOOT ${bootp}
mke2fs -t ext4 -L ROOTFS -b 4096 ${rootfsp}

# Can we mount the new partitions is a repeatable way?
bootpmnt=$(mktemp -d sdbootXXX)
rootfspmnt=$(mktemp -d sdrootfsXXX)

mount ${bootp} ${bootpmnt}
mount ${rootfsp} ${rootfspmnt}

# Mount the image for dumping
loopdevice=$(losetup -f --show ${SD_CARD_IMG})
if [ $? -ne 0 ]; then
	echo "[ERROR]: failed to setup loop device for ${SD_CARD_IMG}"
	exit
fi

device=$(kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1)

sleep 5

# Set up the mapped boot and rootfs partitions of the image
device="/dev/mapper/${device}"
imgbootp=${device}p1
imgrootfsp=${device}p2

# Make mount point directories
imgbootpmnt=$(mktemp -d sdbootXXX)
imgrootfspmnt=$(mktemp -d sdrootfsXXX)

mount ${imgbootp} ${imgbootpmnt}
mount ${imgrootfsp} ${imgrootfspmnt}

# Rsync contents of the boot and rootfs partitions to the SD card
rsync -Hav --progress ${imgbootpmnt}/ ${bootpmnt}
rsync -Hav --progress ${imgrootfspmnt}/ ${rootfspmnt}

sync

umount ${imgbootp}
umount ${imgrootfsp}

rm -r ${imgbootpmnt}
rm -r ${imgrootfspmnt}

echo "--- Removing loop device"
kpartx -dv ${loopdevice}
losetup -d ${loopdevice}

umount ${bootp}
umount ${rootfsp}
rm -r ${bootpmnt}
rm -r ${rootfspmnt}

eject ${SD_CARD_DEV}
