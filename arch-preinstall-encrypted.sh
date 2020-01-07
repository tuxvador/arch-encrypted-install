#!/bin/bash

dev="/dev/"

function check_network() {
	#Check if network interface is connected to internet
	ping -c2 archlinux.org  2>&1 > /dev/null
	if [ $? -ne 0 ]; then
		echo -e "[-] Network configuration not well set... \n[+]Trying to configure network... "
	fi

	Interface=$(ls /sys/class/net | grep '^e')

	dhclient $Interface
	if [ $? -ne 0 ]; then
		echo "[-] could not configure network interface, Stopping Install"
		exit -2
	fi
}

function preinstall() {

	esp=$1
	mount /dev/myvg/root /mnt
	swapon /dev/myvg/swap
	mkdir /mnt/boot/
    mkdir /mnt/efi/
	mount $esp /mnt/efi/

	pacstrap /mnt base linux base-devel sudo wget curl lvm2 i3-wm i3lock i3status i3blocks firefox caja lightdm vim dhcpcd rofi dmenu mesa networkmanager xorg-server xorg-xrandr \
	network-manager-applet lightdm-gtk-greeter fish keepassxc terminator fish git linux-firmware dhclient wifi-menu

	genfstab -U /mnt >> /mnt/etc/fstab
	echo "--------------------------------------------------------------------------"
	cat "/mnt/etc/fstab"
	echo "/efi/EFI/arch /boot none defaults,bind 0 0" >> "/mnt/etc/fstab"

	cp /root/usb/arch-install-encrypted.sh /mnt
	arch-chroot /mnt bash -c "./arch-install-encrypted.sh"
	reboot	
}

function create_containner() {

	block_device=$1
	cryptsetup luksFormat --type luks2 --cipher camellia-xts-plain64 --key-size 512 --iter-time 2000 --pbkdf argon2id --hash sha512 $block_device
	cryptsetup open $block_device cryptlvm
	pvcreate /dev/mapper/cryptlvm
	vgcreate myvg /dev/mapper/cryptlvm
	lvcreate -L 8G myvg -n swap
	lvcreate -l 100%FREE myvg -n root
	lsblk
	read -p "Select ESP partition : " esp
	esp="$dev$esp"
	mkfs.fat -F32 $esp
	mkfs.ext4 /dev/myvg/root
	mkswap /dev/myvg/swap
	preinstall $esp

}

function secure_erase() {

	block_device=$1
	cryptsetup open --type plain -d /dev/urandom/$block_device to_be_wiped
	lsblk
	dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
	cryptsetup close to_be_wiped
	create_containner $block_device

}

function partition_disk() {
	
	lsblk
	read -p "[+] Select device wher to install the Arch-encrypted. Example: sda,nvmen1 : " block_device
	block_device="$dev$block_device"
	read -p "Are you sure : " -n 1 -r; echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "You did not confirm on which device to install, exiting"
		exit -3
	else
		lsblk $block_device
		if [$? -ne 0]; then
			echo "[-] Block device does not exist..., exiting"
			exit -4
		else
			echo "[+] Deleting all partitions on block device ..."
			wipefs -a $block_device
			echo -e "g\nn\n1\n2048\n+550M\nt\n1\np\nn\n2\n\n\nt\n2\n31\np" | fdisk $block_device
			read -p "Does this partition scheme suit you? : " -n 1 -r; echo
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo "You did not confirm. Exiting ..."
				exit -5
			else
				echo "[+] partitionning device... "
				echo -e "g\nn\n1\n2048\n+550M\nt\n1\np\nn\n2\n\n\nt\n2\n31\n\nw" | fdisk $block_device
				echo -e "\n"
				lsblk
				read -p "Select block device partition where to install arch : " block_device
				block_device="$dev$block_device"
				secure_erase $block_device
			fi
		fi
	fi

}

#Check if efi boot
FILE_EFI="/sys/firmware/efi/efivars"
if test -d "$FILE_EFI"; then
	echo "[+] Efi vars exist continuing install"
	check_network
	timedatectl set-ntp true
	partition_disk

else
	echo "[-] The efivars file was not found please disable secureboot and activate uefi boot, Stopping instll"
	exit -1
fi
