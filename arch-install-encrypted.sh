#!/bin/bash

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i "s/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
locale-gen

echo "LC_ADDRESS=fr_FR.UTF-8
LC_COLLATE=fr_FR.UTF-8
LC_CTYPE=fr_FR.UTF-8
LC_IDENTIFICATION=fr_FR.UTF-8
LC_MONETARY=fr_FR.UTF-8
LC_MESSAGES=en_US.UTF-8
LC_MEASUREMENT=fr_FR.UTF-8
LC_NAME=fr_FR.UTF-8
LC_NUMERIC=fr_FR.UTF-8
LC_PAPER=fr_FR.UTF-8
LC_TELEPHONE=fr_FR.UTF-8
LC_TIME=fr_FR.UTF-8
LANG=en_US.UTF-8
LANGUAGE=en_US:en
" > /etc/locale.conf

echo "KEYMAP=fr" > /etc/vconsole.conf

read -p "Enter Hostname : " hostname; echo
echo $hostname > /etc/hostname

echo "127.0.0.1 localhost
127.0.0.1 $hostname
::1       localhost" > /etc/hosts

sed "s/^HOOKS.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 resume filesystems fsck)/g" /etc/mkinitcpio.conf
mkinitcpio -p linux
mkdir -p /efi/EFI/arch
cp -a /boot/vmlinuz-linux /efi/EFI/arch/
cp -a /boot/initramfs-linux.img /efi/EFI/arch/
cp -a /boot/initramfs-linux-fallback.img /efi/EFI/arch/

passwd

pacman -S refind-efi intel-ucode
cp -a /boot/intel-ucode.img /efi/EFI/arch/
refind-install

lsblk
read -p "Please enter block device,Example = cryptlvm : " block_device
uuid=$(id=$(lsblk -f | grep $block_device); echo $id | cut -d ' ' -f3)


echo '"Boot with default options"  "cryptdevice=UUID=$uuid:cryptlvm root=/dev/myvg/root rw add_efi_memmap initrd=/EFI/arch/intel-ucode.img initrd=/EFI/arch/initramfs-%v.img resume=/dev/myvg/swap"
"Boot with fallback initramfs"    "cryptdevice=UUID=$uuid:cryptlvm root=/dev/myvg/root rw add_efi_memmap initrd=/EFI/arch/intel-ucode.img initrd=/EFI/arch/initramfs-%v-fallback.img resume=/dev/myvg/swap"
"Boot to terminal"   "cryptdevice=UUID=$uuid:cryptlvm root=/dev/myvg/root rw add_efi_memmap systemd.unit=multi-user.target resume=/dev/myvg/swap"' > /boot/refind_linux.conf

sed -i "s/\$uuid/$uuid/g" /boot/refind_linux.conf 

cp /boot/refind_linux.conf /efi/EFI/arch/refind_linux.conf





