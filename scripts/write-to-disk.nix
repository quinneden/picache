{
  gptfdisk,
  lib,
  util-linux,
  writeShellScript,
  runCommand,
  ...
}:
let
  binPath = lib.makeBinPath [
    util-linux
    gptfdisk
  ];

  writeToDiskScript = writeShellScript "write-to-disk" ''
    PATH="${binPath}:$PATH"

    tmpDir="$(mktemp -d)"

    trap 'rm -rf "$tmpDir"' EXIT

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

    diskutil list -plist external \
      > "$tmpDir/diskutil_list.plist"

      plutil -r \
      -convert json \
      -o "$tmpDir/diskutil_list.json" \
      "$tmpDir/diskutil_list.plist"

    cp ./result/nixos.img "$tmpDir"
    chmod 644 "$tmpDir/nixos.img"

    diskutil list external
    echo 'Choose disk to write to: (e.g. diskX)'
    read -r DISK

    is_mounted=$(
      jq -r --arg DISK "$DISK" '
        .AllDisksAndPartitions[]
        | select(.DeviceIdentifier == $DISK)
        | .Partitions[].MountPoint
      ' "$tmpDir/diskutil_list.json"
    )

    if [[ -n $is_mounted ]]; then
      diskutil unmountDisk "$DISK" || exit 1
    fi

    wipefs -a /dev/"$DISK"
    sgdisk -Z /dev/"$DISK"

    echo
    confirm "Write to disk?" || exit 1

    dd \
      if="$tmpDir/nixos.img" \
      of="/dev/r$DISK" \
      bs=1M conv=noerror,sync \
      status=progress
  '';
in
runCommand "write-to-disk"
  {
    meta.mainProgram = "write-to-disk";
  }
  ''
    ${writeToDiskScript}
  ''
