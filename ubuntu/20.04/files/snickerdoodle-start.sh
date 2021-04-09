#!/bin/sh

. /lib/lsb/init-functions

HOSTAPD_CONF=/etc/hostapd/hostapd.conf

# Defaults
eth0_netmask=255.255.255.0
eth1_netmask=255.255.255.0

mount="/boot"

#use the 1st partition of sdcard
boot_part="/dev/mmcblk0p1"

#mount boot partition to mount
mount -o rw "$boot_part" "$mount"

[ -f /boot/config.txt ] && . /boot/config.txt

# Update users and passwords
user_mgmt() {
	if [ -n "$update_users" ]; then
		log_action_begin_msg "Updating users"
		for entry in $(echo $update_users | sed "s/,/ /g"); do
			echo $entry | awk -F':' '{
				n = split($0, params, ":")
				for (i = n + 1; i < 8; i++)
					params[i] = ""

				if (length(params[6]) == 0)
					params[6] = sprintf("/home/%s", params[1])

				if (length(params[7]) == 0)
					params[7] = "/bin/bash"

				for (i = 1; i < 8; i++) {
					printf params[i]
					if (i < 7)
						printf ":"
				}
			}' | newusers
			usermod -a -G sudo $(echo "$entry" | awk -F':' '{print $1}')
		done
		sed -i "s/^\(update_users=\).*/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi
}

# Configure wireless access point
config_wireless_ap() {
	if [ -n "$ap_passphrase" ]; then
		log_action_begin_msg "Updating access point passphrase"
		sed -i "s/^#*\(wpa_passphrase=\).*/\1$ap_passphrase/g" $HOSTAPD_CONF
		sed -i "s/^\(ap_passphrase=.*\)/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi

	if [ -n "$ap_ssid" ]; then
		log_action_begin_msg "Updating access point SSID"
		sed -i "s/^#*\(ssid=\).*$/\1$ap_ssid/g" $HOSTAPD_CONF
		sed -i "s/^\(ap_ssid=.*\)/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi

	if [ -n "$ap_hw_mode" ]; then
		log_action_begin_msg "Updating access point Hardware Mode"
		sed -i "s/^#*\(hw_mode=\).*$/\1$ap_hw_mode/g" $HOSTAPD_CONF
		sed -i "s/^\(ap_hw_mode=.*\)/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi

	if [ -n "$ap_channel" ]; then
		log_action_begin_msg "Updating access point Channel"
		sed -i "s/^#*\(channel=\).*$/\1$ap_channel/g" $HOSTAPD_CONF
		sed -i "s/^\(ap_channel=.*\)/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi

	if [ -n "$ap_address" ]; then
		log_action_begin_msg "Updating access point gateway address"
		sed -i "s/^\([ \t]*address\).*/\1 $ap_address/g" /etc/network/interfaces.d/wlan1
		sed -i "s/\(\t*option routers\).*/\1 $ap_address;/g" /etc/dhcp/dhcpd.conf
		sed -i "s/\(subnet\).*/\1 ${ap_address%.*}.0 netmask 255.255.255.0 {/g" /etc/dhcp/dhcpd.conf
		sed -i "s/\(\t*range\).*/\1 ${ap_address%.*}.10 ${ap_address%.*}.100;/g" /etc/dhcp/dhcpd.conf
		sed -i "s/\(\t*option broadcast-address\).*/\1 ${ap_address%.*}.255;/g" /etc/dhcp/dhcpd.conf
		sed -i "s/^\(ap_address=.*\)/#\1/g" /boot/config.txt
		log_action_end_msg $?
	fi
}

# Configure wireless station network
config_wireless_sta() {
	if [ -n "$sta_mode" ]; then
		log_action_begin_msg "Adding station network"

# If the network already exists in the wpa_supplicant.conf, delete it
sed -i -f - /etc/wpa_supplicant.conf <<EOF
/^[\s]*network[\s]*=/{
        :1
        /{/!N
	/{/!b1
	:2
	/}/!N
        /}/!b2
        /ssid=\"*$sta_ssid\"*/d
}
EOF
		case "$sta_mode" in
			wpa|wpa2)
cat >> /etc/wpa_supplicant.conf <<EOF
network={
	auth_alg=OPEN
	key_mgmt=WPA-PSK
	ssid="$sta_ssid"
	psk="$sta_key"
	proto=RSN
	mode=0
}
EOF
				;;
			wep)
cat >> /etc/wpa_supplicant.conf <<EOF
network={
	auth_alg=OPEN
	key_mgmt=NONE
	ssid="$sta_ssid"
	wep_key0="$sta_key"
	mode=0
}
EOF
				;;
			open)
cat >> /etc/wpa_supplicant.conf <<EOF
network={
	auth_alg=OPEN
	key_mgmt=NONE
	ssid="$sta_ssid"
	mode=0
}
EOF
				;;
			*)
				echo "Unknown value for sta_mode: $sta_mode" >&2
				exit 3
				;;
		esac
		log_action_end_msg $?
	fi

	sed -i "s/^\(sta_mode=\).*/#\1/g" /boot/config.txt
	sed -i "s/^\(sta_ssid=\).*/#\1/g" /boot/config.txt
	sed -i "s/^\(sta_key=\).*/#\1/g" /boot/config.txt
}

# Configure ethernet network(s)
config_ethernet() {
	if [ -n "$eth0_mode" ]; then
		log_action_begin_msg "Configuring eth0 network settings"
		case "$eth0_mode" in
			dhcp)
cat > /etc/network/interfaces.d/eth0 <<EOF
allow-hotplug eth0
iface eth0 inet $eth0_mode
EOF
				;;
			static|manual)
cat > /etc/network/interfaces.d/eth0 <<EOF
auto eth0
iface eth0 inet $eth0_mode
	address $eth0_address
	netmask $eth0_netmask
EOF
				;;
			disabled)
				rm -f /etc/network/interfaces.d/eth0
				;;
			*)
				echo "Unknown value for eth0_mode: $eth0_mode" >&2
				exit 3
				;;
		esac

		[ -f /etc/network/interfaces.d/eth0 ] && chmod 600 /etc/network/interfaces.d/eth0
		log_action_end_msg $?

		sed -i "s/^\(eth0_mode=.*\)/#\1/g" /boot/config.txt
		sed -i "s/^\(eth0_address=.*\)/#\1/g" /boot/config.txt
		sed -i "s/^\(eth0_netmask=.*\)/#\1/g" /boot/config.txt

	fi

	if [ -n "$eth1_mode" ]; then
		log_action_begin_msg "Configuring eth1 network settings"
		case "$eth1_mode" in
			dhcp)
cat > /etc/network/interfaces.d/eth1 <<EOF
allow-hotplug eth1
iface eth1 inet $eth1_mode
EOF
				;;
			static|manual)
cat > /etc/network/interfaces.d/eth1 <<EOF
auto eth1
iface eth1 inet $eth1_mode
	address $eth1_address
	netmask $eth1_netmask
EOF
				;;
			disabled)
				rm -f /etc/network/interfaces.d/eth1
				;;
			*)
				echo "Unknown value for eth1_mode: $eth1_mode" >&2
				exit 3
				;;
		esac

		[ -f /etc/network/interfaces.d/eth1 ] && chmod 600 /etc/network/interfaces.d/eth1
		log_action_end_msg $?

		sed -i "s/^\(eth1_mode=.*\)/#\1/g" /boot/config.txt
		sed -i "s/^\(eth1_address=.*\)/#\1/g" /boot/config.txt
		sed -i "s/^\(eth1_netmask=.*\)/#\1/g" /boot/config.txt

	fi
}

user_mgmt		|| exit 1
config_wireless_ap	|| exit 1
config_wireless_sta	|| exit 1
config_ethernet		|| exit 1

if [ -n "$eth0_mode" ] || [ -n "$eth1_mode" ] ||
   [ -n "$ap_address" ] || [ -n "$ap_passphrase" ] ||
   [ -n "$ap_ssid" ] || [ -n "$ap_hw_mode" ] ||
   [ -n "$ap_channel" ] || [ -n "$ap_address" ] ||
   [ -n "$sta_mode" ]; then
	/sbin/reboot	
fi
