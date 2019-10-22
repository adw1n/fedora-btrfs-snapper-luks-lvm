#!/bin/bash
# recommended read
# https://dustymabe.com/2019/01/06/fedora-btrfs-snapper---the-fedora-29-edition/
# https://dustymabe.com/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/
set -ex

readonly DRIVE='/dev/sda'
readonly LVM_VG='vgroot'
readonly LVM_ROOT_PARTITION_LV='lvroot'

if [ -d /sys/firmware/efi ]; then
  echo 'UEFI installation'
  UEFI='true'
else
  echo 'BIOS installation'
  UEFI='false'
fi
# gdisk -l $DRIVE | grep "using GPT"

mount --bind / /mnt
cp -a /boot/* /mnt/boot/
cp -a /boot/.vmlinuz-* /mnt/boot/
diff -ur /boot/ /mnt/boot/
if "${UEFI}"; then
  rm -rf /mnt/boot/efi
fi
umount /mnt

BOOT_PARTITION="$(mount -l | grep /boot | grep -v /boot/efi | awk '{ print $1 }')"
BOOT_PARTITION_NO="${BOOT_PARTITION#$DRIVE}"

if "${UEFI}"; then
  BOOT_EFI_PARTITION="$(mount -l | grep /boot/efi | awk '{ print $1 }')"
fi

echo "wiping /boot partition ${BOOT_PARTITION}, partition number ${BOOT_PARTITION_NO} with random data"

read -rp 'Continue (y/n)?' choice
case "${choice}" in
  y|Y ) ;;
  * ) echo 'bailing out'; exit 1;
esac

if "${UEFI}"; then
  umount /boot/efi
fi
umount /boot

# TODO find a better way that doesn't ignore the exit code
# TODO sync after each time it finishes
# TODO override with encrypted random data
seq 3 | xargs -I @ dd if=/dev/urandom of="${BOOT_PARTITION}" status=progress || true

sync

fdisk /dev/sda <<EOF
p
d
${BOOT_PARTITION_NO}
w
EOF
# Failed to remove partition3 from system: Device or resource busy
# kernel still uses the old partitions. The new table will be used at the next reboot.

if "${UEFI}"; then
  mkdir /boot/efi
  mount "${BOOT_EFI_PARTITION}" /boot/efi
fi

cp /etc/fstab /etc/fstab.backup
sed -i '/\/boot.*ext4/d' /etc/fstab  # delete /boot entry

touch /.autorelabel

btrfs subvolume delete /var/lib/machines
btrfs quota enable /
dnf install -y snapper python3-dnf-plugins-extras-snapper
setenforce 0
snapper --config=root create-config /
setenforce 1
echo "/dev/${LVM_VG}/${LVM_ROOT_PARTITION_LV} /.snapshots btrfs subvol=.snapshots 0 0" >> /etc/fstab

echo GRUB_ENABLE_CRYPTODISK='y' >> /etc/default/grub
echo SUSE_BTRFS_SNAPSHOT_BOOTING='true' >> /etc/default/grub

if "${UEFI}"; then
  dnf install -y grub2-efi-x64-modules
  grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
  grub2-install --efi-directory=/boot/efi --boot-directory=/boot/efi/EFI/fedora --debug
else
  grub2-mkconfig -o /boot/grub2/grub.cfg
  grub2-install "${DRIVE}"
fi

# new kernel install creates a new entry in /boot/loader/entries with correct vmlinuz path (with /boot prefix)
dnf update -y kernel

echo 'Ready to reboot'
