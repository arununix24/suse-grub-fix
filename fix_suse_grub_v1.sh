	#!/bin/bash

	#author: @Arun Kumar
	#name: fix_suse_grub_v1.sh
	#description: A focused openSUSE boot repair script that detects the BTRFS snapshot subvolume and reinstalls GRUB to the primary Ubuntu disk. It includes enhanced debugging output to assist in troubleshooting if the expected subvolume is not found.
	#date: 2024-06-01


	# Ensure the script is run as root
	if [[ $EUID -ne 0 ]]; then
	echo "Error: This script must be run as root (sudo)." 
	exit 1
	fi

	echo "--- Initializing Debug-Ready openSUSE Boot Fix ---"

	# 1. AUTO-DETECT UBUNTU DISK
	UBUNTU_DISK=$(lsblk -no PKNAME $(findmnt -nvo SOURCE /) | head -n1)
	UBUNTU_DISK="/dev/$UBUNTU_DISK"

	if [ -b "$UBUNTU_DISK" ]; then
		echo "[OK] Primary Ubuntu disk: $UBUNTU_DISK"
	else
		echo "[FAIL] Could not determine Ubuntu disk."
		exit 1
	fi

	# 2. AUTO-DETECT OPENSUSE PARTITION
	# We specifically look for the BTRFS partition that is NOT currently mounted as root
	SUSE_PART=$(blkid -t TYPE=btrfs -o device | grep -v $(findmnt -nvo SOURCE /) | head -n1)

	if [ -z "$SUSE_PART" ]; then
		echo "[FAIL] No openSUSE BTRFS partition found."
		exit 1
	fi
	echo "[OK] Testing partition: $SUSE_PART"

	# 3. PROBE FOR SUBVOLUMES
	MOUNT_TEMP="/mnt/suse_probe"
	mkdir -p $MOUNT_TEMP
	mount -o subvolid=5 "$SUSE_PART" $MOUNT_TEMP

	# Search for the standard snapshot path
	SNAPSHOT_PATH=$(btrfs subvolume list $MOUNT_TEMP | grep "@/.snapshots/1/snapshot" | awk '{print $NF}' | head -n1)

	if [ -z "$SNAPSHOT_PATH" ]; then
		echo "[FAIL] Could not locate @/.snapshots/1/snapshot on $SUSE_PART."
		echo "--- DEBUG: Found these subvolumes instead ---"
		btrfs subvolume list $MOUNT_TEMP
		umount $MOUNT_TEMP
		exit 1
	fi

	umount $MOUNT_TEMP
	echo "[OK] Found active subvolume: $SNAPSHOT_PATH"

	# 4. MOUNT AND VALIDATE
	MOUNT_TARGET="/mnt/suse_fix"
	mkdir -p $MOUNT_TARGET
	mount -o subvol="$SNAPSHOT_PATH" "$SUSE_PART" $MOUNT_TARGET

	if [ ! -f "$MOUNT_TARGET/bin/bash" ]; then
		echo "[FAIL] /bin/bash not found in $SNAPSHOT_PATH. This may not be the root partition."
		umount $MOUNT_TARGET
		exit 1
	fi

	# 5. BIND AND REPAIR
	echo "[+] Binding system directories..."
	for dir in /dev /proc /sys; do
		mount --bind $dir $MOUNT_TARGET$dir
	done

	echo "[+] Reinstalling openSUSE GRUB to $UBUNTU_DISK..."
	chroot $MOUNT_TARGET /bin/bash <<EOF
	grub2-install $UBUNTU_DISK
	grub2-mkconfig -o /boot/grub2/grub.cfg
	exit
	EOF

	# 6. CLEANUP
	echo "[+] Cleaning up..."
	umount $MOUNT_TARGET/dev $MOUNT_TARGET/proc $MOUNT_TARGET/sys
	umount $MOUNT_TARGET
	update-grub

	echo "--- SUCCESS ---"
