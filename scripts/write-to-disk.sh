#!/usr/bin/env bash

confirm() {
  while true; do
    read -r -n 1 -p "$1 [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) echo ;;
    esac
  done
}

tmpDir=$(mktemp -d)
trap 'rm -rf $tmpDir' EXIT

imgPath=$(find ./result -follow -iname "*.img")

cp $imgPath $tmpDir/nixos.img
chmod 644 "$tmpDir/nixos.img"

diskutil list external physical
echo 'Choose disk to write to: (e.g. diskX)'
read -r DISK

diskutil list -plist external | plutil -convert json -o $tmpDir/diskutil_list.json -

diskutil unmountDisk $DISK || true
diskutil eraseDisk -noEFI free free $DISK

echo
confirm "Write to disk?" || exit 1

sync; sudo dd if=$tmpDir/nixos.img of=/dev/r$DISK bs=1M conv=noerror,sync status=progress; sync
sudo purge
