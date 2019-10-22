# Fedora 30 linux install with luks + encrypted boot partition + btrfs snapper walkthrough (both EFI and BIOS)

First we install Fedora with unencrypted boot partition only to move the boot folder to the encrypted root partition after reboot.

![Select Blivet-GUI](1_anaconda_pick_blivet.png)
Skip /boot/efi partition for BIOS installs
![boot and efi partitions](2_anaconda_boot_and_efi_partitions.png)
![encrypted volume group](3_anaconda_volume_group.png)
![root logical volume](4_anaconda_lv_root.png)
![swap logical volume](5_anaconda_lv_swap.png)
![home logical volume](6_anaconda_lv_home.png)
![finish](7_anaconda_accept.png)

After reboot modify [migrate.sh](migrate.sh) to your liking and run it. Script [migrate.sh](migrate.sh) should:

1. Move the unencrypted /boot partition to /boot folder on the encrypted root partition.
2. Override the old /boot partition with random data and delete it.
3. Install and configure snapper.
4. Refresh grub config.
