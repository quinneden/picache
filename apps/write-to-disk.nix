{ pkgs, self, ... }:
let
  inherit (pkgs) lib writeShellApplication;
  inherit (self.packages.${pkgs.system}) image;

  diskImage = image.name;

  writeToDiskScript = ''
    tmpDir="$(mktemp -d)"

    trap 'rm -rf "$tmpDir"' exit

    confirm() {
      if ''${"CONFIRM:-true"}; then
        while true; do
          read -r -n 1 -p "$1 [y/n]: " REPLY
          case $REPLY in
            [yY]) echo ; return 0 ;;
            [nN]) echo ; return 1 ;;
            *) echo ;;
          esac
        done
      fi
    }

    cp ${image + "/sd-image/" + diskImage} "$tmpDir"
    chmod 644 "$tmpDir/${diskImage}"

    diskutil list external
    echo 'Choose disk to write to: (e.g. diskX)'
    read -r DISK

    sudo wipefs -a /dev/"$DISK"
    sudo sgdisk -Z /dev/"$DISK"

    echo
    confirm "Write to disk?" || exit 1

    sudo dd if="$tmpDir/${diskImage}" of="/dev/$DISK" bs=1M conv=noerror,sync status=progress
  '';
in
with lib;
{
  type = "app";
  program = getExe (writeShellApplication {
    name = "write-to-disk";
    runtimeInputs = with pkgs; [
      util-linux
      gptfdisk
    ];
    text = writeToDiskScript;
  });
}
