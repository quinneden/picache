#!/usr/bin/env nix-shell
#! nix-shell -i bash -p parted btrfs-progs gptfdisk wget unzip

set -xe -o pipefail

targetDisk="$1"

if [[ -z $targetDisk || $targetDisk != /dev/* ]]; then
  echo "Please provide a valid disk path (e.g /dev/sdX)" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

wipefs -a "$targetDisk"
sgdisk -Z "$targetDisk"
sleep 0.5

parted -a optimal "$targetDisk" -- mklabel gpt
parted -a optimal "$targetDisk" -- mkpart ESP fat32 1MiB 513MiB
parted -a optimal "$targetDisk" -- set 1 esp on
parted -a optimal "$targetDisk" -- mkpart primary 513MiB 100%

mkfs.fat -F 32 -n boot "${targetDisk}1"
mkfs.btrfs -L "nixos" "${targetDisk}2"

mkdir -p /mnt
mount "${targetDisk}2" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix

umount /mnt

mount -t btrfs -o compress=zstd,subvol=@,noatime "${targetDisk}2" /mnt

mkdir -p /mnt/{home,nix}

mount -t btrfs -o compress=zstd,subvol=@home "${targetDisk}2" /mnt/home
mount -t btrfs -o compress=zstd,noatime,subvol=@nix "${targetDisk}2" /mnt/nix

mkdir /mnt/boot

mount "${targetDisk}1" /mnt/boot

nixos-generate-config --root /mnt --show-hardware-config | tee hardware.nix

wget "https://github.com/pftf/RPi4/releases/download/v1.41/RPi4_UEFI_Firmware_v1.41.zip"
unzip -d /mnt/boot "RPi4_UEFI_Firmware_*.zip" -x "*.md"
rm RPi4_UEFI_Firmware_*.zip
