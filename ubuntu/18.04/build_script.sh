#!/bin/bash

UBOOT_SOURCE_URL=https://github.com/krtkl/snickerdoodle-u-boot.git
LINUX_SOURCE_URL=https://github.com/krtkl/snickerdoodle-linux.git
DTS_SOURCE_URL=https://github.com/krtkl/snickerdoodle-dts.git
DTC_SOURCE_URL=https://github.com/dgibson/dtc.git
WL18XX_FW_SOURCE_URL=git://git.ti.com/wilink8-wlan/wl18xx_fw.git
WLCONF_SOURCE_URL=https://github.com/krtkl/wlconf.git

rootdir=`pwd`
rootfs=$rootdir/buildfs
boards=( "snickerdoodle" "snickerdoodle_black" "snickerdoodle_prime" "snickerdoodle_one" )

#
# Grab sources
#
get_sources() {
# Download the U-Boot source
git clone $UBOOT_SOURCE_URL

# Download the Linux source
git clone $LINUX_SOURCE_URL

# Download device tree compiler source
git clone $DTC_SOURCE_URL
git clone $DTS_SOURCE_URL

# Download supplementary wireless firmware
git clone $WL18XX_FW_SOURCE_URL

# Download wirless configuration utility
git clone $WLCONF_SOURCE_URL

}

#
# Bootstrap the filesystem
#
bootstrap_system() {

debootstrap --verbose --foreign --arch armhf bionic $rootfs

cp /usr/bin/qemu-arm-static $rootfs/usr/bin/

LANG=C chroot $rootfs/ /debootstrap/debootstrap --second-stage

# Configure filesystem

# Set up FSTAB
cat > $rootfs/etc/fstab << "EOF"
# Default snickerdoodle File System Table
# <file system>		<mount>		<type>		<options>	<dump>	<pass>
/dev/mmcblk0p1		/boot		vfat		defaults	0	0
/dev/mmcblk0p2		/		ext4		defaults	0	0
configfs		/config		configfs	defaults	0	0
tmpfs			/tmp		tmpfs		defaults	0	0

EOF

# Set the hostname
cat > $rootfs/etc/hostname << "EOF"
snickerdoodle
EOF

cat > $rootfs/etc/hosts << "EOF"
127.0.0.1	localhost snickerdoodle
::1		localhost ip6-localhost ip6-loopback
fe00::0		ip6-localnet
ff00::0		ip6-mcastprefix
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

EOF

}

#
# Configure networking
#
configure_networking() {

# Configure DHCP clients
cat > $rootfs/etc/netplan/99_config.yaml << "EOF"
network:
  version: 2
  renderer: networkd
  ethernets:
    wlan0:
      dhcp4: true

network:
  version: 2
  renderer: networkd
  ethernets:
    wlan1:
      addresses:
        - 10.0.110.2/24
      gateway4: 10.0.110.1
EOF

cat > $rootfs/etc/resolv.conf << "EOF"
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

cat > $rootfs/etc/wpa_supplicant.conf << "EOF"
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=0
update_config=1

EOF

chmod 0600 $rootfs/etc/wpa_supplicant.conf

# configure the DHCP server for the wireless access point
sed -i -e 's/^\(INTERFACES=\).*/\1\"wlan1\"/' $rootfs/etc/default/isc-dhcp-server

mkdir -p $rootfs/etc/snickerdoodle/accesspoint

# Add script to bringup the wireless access point
cat > $rootfs/etc/snickerdoodle/accesspoint/ifupdown.sh << "EOF"
#!/bin/sh

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# On Debian GNU/Linux systems, the text of the GPL license,
# version 2, can be found in /usr/share/common-licenses/GPL-2.

# quit if we're called for lo
if [ "$IFACE" = lo ]; then
	exit 0
fi

# using hostapd config
if [ -n "$IF_HOSTAPD" ]; then
	HOSTAPD_CONF="$IF_HOSTAPD"
else
	exit 0
fi


accesspoint_msg () {
	case "$1" in
		verbose)
			shift
			echo "$HOSTAPD_PNAME: $@" > "$TO_NULL"
			;;
		stderr)
			shift
			echo "$HOSTAPD_PNAME: $@" > /dev/stderr
			;;
		*)
			;;
		esac
}

init_accesspoint () {
	echo 1 > /proc/sys/net/ipv4/ip_forward

	if [ ! -d /sys/class/net/$IFACE ]; then
		iw phy `ls /sys/class/ieee80211/` interface add $IFACE type managed
	fi

	HWID=`sed '{s/://g; s/.*\([0-9a-fA-F]\{6\}$\)/\1/}' /sys/class/net/$IFACE/address`
	DEFAULT_SSID=`hostname`-$HWID

	if [ -z $(grep -e "^ssid *=.*" $HOSTAPD_CONF) ]; then
		if [ -n $(grep -e "^#ssid *=.*" $HOSTAPD_CONF) ]; then
			sed -ie "s/^#\(ssid *= *\).*$/\1$DEFAULT_SSID/g" $HOSTAPD_CONF
		fi
	fi
}

case "$MODE" in
	start)
		case "$PHASE" in
			pre-up)
				init_accesspoint || exit 1
				;;
			*)
				accesspoint_msg stderr "unknown phase: \"$PHASE\""
				exit 1
				;;
		esac
		;;
	stop)
		case "$PHASE" in
			*)
				accesspoint_msg stderr "unknown phase: \"$PHASE\""
				exit 1
				;;
		esac
		;;
	*)
		accesspoint_msg stderr "unknown mode: \"$MODE\""
		exit 1
		;;
esac

exit 0

EOF

chmod 755 $rootfs/etc/snickerdoodle/accesspoint/ifupdown.sh

# Link to the script for interface bringup
ln -s ../../snickerdoodle/accesspoint/ifupdown.sh $rootfs/etc/network/if-pre-up.d/accesspoint

# Default hostapd configuration

cat > $rootfs/etc/hostapd.conf << "EOF"

interface=wlan1
driver=nl80211
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
ctrl_interface=/var/run/hostapd
#ssid=
country_code=US
ieee80211d=1
ieee80211h=1
hw_mode=g
channel=11
beacon_int=100
dtim_period=2
max_num_sta=10
supported_rates=10 20 55 110 60 90 120 180 240 360 480 540
basic_rates=10 20 55 110 60 120 240
preamble=1
macaddr_acl=0
auth_algs=3
ignore_broadcast_ssid=0
tx_queue_data3_aifs=7
tx_queue_data3_cwmin=15
tx_queue_data3_cwmax=1023
tx_queue_data3_burst=0
tx_queue_data2_aifs=3
tx_queue_data2_cwmin=15
tx_queue_data2_cwmax=63
tx_queue_data2_burst=0
tx_queue_data1_aifs=1
tx_queue_data1_cwmin=7
tx_queue_data1_cwmax=15
tx_queue_data1_burst=3.0
tx_queue_data0_aifs=1
tx_queue_data0_cwmin=3
tx_queue_data0_cwmax=7
tx_queue_data0_burst=1.5
wme_enabled=1
uapsd_advertisement_enabled=1
wme_ac_bk_cwmin=4
wme_ac_bk_cwmax=10
wme_ac_bk_aifs=7
wme_ac_bk_txop_limit=0
wme_ac_bk_acm=0
wme_ac_be_aifs=3
wme_ac_be_cwmin=4
wme_ac_be_cwmax=10
wme_ac_be_txop_limit=0
wme_ac_be_acm=0
wme_ac_vi_aifs=2
wme_ac_vi_cwmin=3
wme_ac_vi_cwmax=4
wme_ac_vi_txop_limit=94
wme_ac_vi_acm=0
wme_ac_vo_aifs=2
wme_ac_vo_cwmin=2
wme_ac_vo_cwmax=3
wme_ac_vo_txop_limit=47
wme_ac_vo_acm=0
ap_max_inactivity=10000
disassoc_low_ack=1
ieee80211n=1
ht_capab=[SHORT-GI-20][GF]
wep_rekey_period=0
eap_server=1
own_ip_addr=127.0.0.1
wpa=2
wpa_passphrase=snickerdoodle
wpa_group_rekey=0
wpa_gmk_rekey=0
wpa_ptk_rekey=0
ap_table_max_size=255
ap_table_expiration_time=60
wps_state=2
ap_setup_locked=1
device_name=snickerdoodle
manufacturer=krtkl
model_name=TI_connectivity_module
model_number=wl18xx
config_methods=virtual_display virtual_push_button keypad

EOF

chmod 600 $rootfs/etc/hostapd.conf

cat > $rootfs/etc/dhcp/dhcpd.conf << "EOF"
#
# Configuration file for ISC dhcpd for Debian
#

ddns-update-style none;
log-facility local7;

subnet 10.0.110.0 netmask 255.255.255.0 {
	range				10.0.110.10	10.0.110.100;
	option routers			10.0.110.2;
	option broadcast-address	10.0.110.255;
	option domain-name		"local";
	default-lease-time		600;
	max-lease-time			7200;
}

EOF

chmod 600 $rootfs/etc/dhcp/dhcpd.conf

}

#
# Configure wireless
#
configure_wireless() {

	TI_FW_PATH=$rootfs/lib/firmware/ti-connectivity

	make -C $rootdir/wlconf

	if [ ! -d $TI_FW_PATH ]; then
		mkdir -p $TI_FW_PATH
	fi

	cp $rootdir/wlconf/wl18xx-conf-default.bin $TI_FW_PATH/wl18xx-conf.bin
	cp $rootdir/wl18xx_fw/wl18xx-fw-4.bin $rootfs/lib/firmware/ti-connectivity/wl18xx-fw-4.bin

	chmod 755 -R $rootfs/lib/firmware/ti-connectivity
}

#
# Configure packages
#
configure_packages() {

cat > $rootfs/etc/apt/sources.list << "EOF"
deb http://ports.ubuntu.com/ubuntu-ports bionic main universe

EOF

# Set up mount points
mount -t proc proc $rootfs/proc
mount -o bind /dev $rootfs/dev
mount -o bind /dev/pts $rootfs/dev/pts

#-------------------------------------------------------------------------------
# Install packages
#-------------------------------------------------------------------------------

packages="ethtool i2c-tools apache2 php libapache2-mod-php openssh-server crda \
iw wpasupplicant hostapd isc-dhcp-server isc-dhcp-client build-essential bison \
flex python3.5 iperf3 htop usbutils xterm parted"

cat > $rootfs/third-stage << EOF
#!/bin/bash

apt update && apt upgrade
apt -y install git-core binutils ca-certificates initramfs-tools u-boot-tools
apt -y install locales console-common less nano git sudo manpages
apt -y install $packages
apt -y autoremove

# Add default user
useradd -m -G sudo -U -p $(openssl passwd -crypt "snickerdoodle") admin
passwd -e admin

rm -f /third-stage

EOF

chmod +x $rootfs/third-stage
LANG=C chroot $rootfs /third-stage

umount $rootfs/dev/pts
umount $rootfs/dev
umount $rootfs/proc
}

configure_special() {

cat > $rootfs/etc/init.d/firstboot << "EOF"
#!/bin/sh
### BEGIN INIT INFO
# Provides:		firstboot
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Perform preparations for first boot
# Description:
### END INIT INFO

. /lib/lsb/init-functions

resize_rootfs() {

	log_daemon_msg "Resizing root filesystem to disk" &&
	parted --script /dev/mmcblk0 resizepart 2 100% &&
	resize2fs /dev/mmcblk0p2 &&
	rm /etc/init.d/firstboot &&
	update-rc.d firstboot remove &&
	log_end msg $?
}

case "$1" in
	start)
		resize_rootfs	|| exit 1
		;;
	*)
		echo "Usage: $0 start" >&2
		exit 3
		;;
esac
EOF

cat > $rootfs/final-stage << "EOF"

chmod +x /etc/init.d/firstboot
update-rc.d firstboot defaults

rm -f /final-stage

EOF

chmod +x $rootfs/final-stage
LANG=C chroot $rootfs /final-stage

}


#
# Perform cleanup on the filesystem
#
cleanup_system() {

cat > $rootfs/cleanup << "EOF"
#!/bin/bash

rm -rf /root/.bash_history
apt update
apt clean
rm -f /cleanup
rm -f /usr/bin/qemu*

EOF

chmod +x $rootfs/cleanup
LANG=C chroot $rootfs /cleanup

}


#
# Build device tree
#
build_dtb() {

make -C $rootdir/dtc
export PATH=$rootdir/dtc:$PATH

make -C $rootdir/snickerdoodle-dts

}


#
# U-Boot build
#
build_u_boot() {

export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-

for board in "${boards[@]}"; do

make -C $rootdir/snickerdoodle-u-boot ${board}_defconfig
make -C $rootdir/snickerdoodle-u-boot
#export PATH=$rootdir/snickerdoodle-u-boot/tools:$PATH

if [ ! -d "$rootdir/${board}BOOT" ]; then
	mkdir $rootdir/${board}BOOT
fi

cp $rootdir/snickerdoodle-u-boot/u-boot $rootdir/${board}BOOT/u-boot.elf

done

}


#
# Linux kernel build
#
build_kernel() {

export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-
export LOADADDR=0x8000
export INSTALL_MOD_PATH=$rootfs
export INSTALL_HDR_PATH=$rootfs/usr
make -C $rootdir/snickerdoodle-linux snickerdoodle_defconfig
make -C $rootdir/snickerdoodle-linux uImage
make -C $rootdir/snickerdoodle-linux modules
make -C $rootdir/snickerdoodle-linux modules_install
make -C $rootdir/snickerdoodle-linux headers_install

}

#
# Build FSBL
#
build_fsbl() {
make -C $rootdir/hw

}

#
# Create boot.bin
#
create_boot() {

for board in "${boards[@]}"; do

cp $rootdir/snickerdoodle-dts/`echo ${board} | tr _ -`.dtb $rootdir/${board}BOOT/devicetree.dtb
cp $rootdir/hw/${board}.elf $rootdir/${board}BOOT/fsbl.elf
cp $rootdir/snickerdoodle-linux/arch/arm/boot/uImage $rootdir/${board}BOOT/uImage

cat > $rootdir/${board}BOOT/bootimage.bif << EOF
image : {
        [bootloader] $rootdir/${board}BOOT/fsbl.elf
        $rootdir/${board}BOOT/u-boot.elf
}
EOF

bootgen -w -image $rootdir/${board}BOOT/bootimage.bif -o $rootdir/${board}BOOT/boot.bin

# Set the configuration in the uEnv.txt file
cat > $rootdir/${board}BOOT/uEnv.txt << "EOF"
bootargs=console=ttyPS0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rw rootwait earlyprink uio_pdrv_genirq.of_id=krtkl,generic-uio,ui_pdrv
script_image=uboot.scr
script_load_address=0x4000000
uenvcmd=if test -e mmc 0 ${script_image}; then load mmc 0 ${script_load_address} ${script_image} && source ${script_load_address}; fi

EOF

cat > boot-scr.tmp << "EOF"

if test -e mmc 0 ${bitstream_image}; then
  echo Loading bitstream from ${bitstream_image}
  load mmc 0 ${loadbit_addr} ${bitstream_image} && fpga loadb 0 ${loadbit_addr} ${filesize};
else
  echo No bitstream present. Bitstream will not be loaded.
fi


if test -e mmc 0 ${kernel_image}; then
  fatload mmc 0 ${kernel_load_address} ${kernel_image};
  fatload mmc 0 ${devicetree_load_address} ${devicetree_image};
  if test -e mmc 0 ${ramdisk_image}; then
    fatload mmc 0 ${ramdisk_load_address} ${ramdisk_image};
    bootm ${kernel_load_address} ${ramdisk_load_address} ${devicetree_load_address};
  else
    bootm ${kernel_load_address} - ${devicetree_load_address};
  fi
fi
EOF

mkimage -A arm -T script -C none -n "snickerdoodle Boot Script" -d boot-scr.tmp $rootdir/${board}BOOT/uboot.scr

rm boot-scr.tmp

done

}

#
# Create SD card image
#
create_card() {

for board in "${boards[@]}"; do

dd conv=sync,noerror if=/dev/zero of=$board.img bs=1M count=1024

parted $board.img --script -- mklabel msdos
parted $board.img --script -- mkpart primary fat32 1MiB 128MiB
parted $board.img --script -- mkpart primary ext4 128MiB 100%

loopdevice=`losetup -f --show $board.img`
device=`kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`

sleep 3

bootp="/dev/mapper/${device}p1"
rootp="/dev/mapper/${device}p2"

mkfs.vfat -n BOOT $bootp
mke2fs -t ext4 -L ROOTFS -b 4096 $rootp

bootmnt=$(mktemp -d bootXXXXXX)
rootmnt=$(mktemp -d rootXXXXXX)

mount $bootp $bootmnt
mount $rootp $rootmnt

rsync -Hav $rootdir/${board}BOOT/ $bootmnt/
rsync -Hav $rootfs/ $rootmnt/

sync

umount $bootmnt
umount $rootmnt

kpartx -dv $loopdevice
losetup -d $loopdevice

rm -r $bootmnt
rm -r $rootmnt

gzip $board.img

done

}

case "$1" in
init)
	get_sources		|| exit 1
	;;
bootstrap)
	bootstrap_system	|| exit 1
	;;
finish)
	cleanup_system		|| exit 1
	;;
all)
	get_sources		|| exit 1
	bootstrap_system	|| exit 1
	configure_packages	|| exit 1
	configure_wireless	|| exit 1
	configure_networking	|| exit 1
	cleanup_system		|| exit 1
    	build_u_boot		|| exit 1
    	build_kernel		|| exit 1
	build_dtb		|| exit 1
    	create_boot		|| exit 1
	create_card		|| exit 1
	;;
uboot)
	build_u_boot		|| exit 1
	;;
rootfs)
	bootstrap_system	|| exit 1
	configure_packages	|| exit 1
	configure_special	|| exit 1
	configure_wireless	|| exit 1
	configure_networking	|| exit 1
	cleanup_system		|| exit 1
	;;
boot)
	shift
	build_fsbl $@		|| exit 1
	;;
system)
	build_u_boot		|| exit 1
	build_kernel		|| exit 1
	build_dtb		|| exit 1
	create_boot		|| exit 1
	;;
card)
	create_card		|| exit 1
	;;
*)
	echo "ERROR: invalid command $1"
	exit  1
	;;
esac
